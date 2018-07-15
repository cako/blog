#!/usr/bin/env python2

import requests
from bs4 import BeautifulSoup, Comment
import os.path
import re
import pandas as pd
import numpy as np
from collections import OrderedDict
from os.path import join
from matplotlib import cm

course_code_regex = re.compile(r"[A-Z]{4}\d{4,}")

DPRS_URL = 'http://www.drps.ed.ac.uk/17-18/dpt/'

class Course(object):
    def __init__(self, code=None, urlid=None, title=None, required=None,
            recommended=None):
        self.code = code
        self.urlid = urlid
        self.title = title
        self.required = required
        self.recommended = recommended
    def __repr__(self):
        return "Course(code=%s, urlid=%s, title=%s, required=%s, recommended=%s)" % (
                self.code, self.urlid, self.title, self.required, self.recommended)


def scrape_urlid(urlid):
    print("Parsing %s" % urlid)
    if os.path.isfile(join('data', urlid)):
        with open(join('data', urlid), 'r') as content:
            soup = BeautifulSoup(content.read(), "lxml")
    else:
        url = DPRS_URL + urlid
        response = requests.get(url, stream=True)
        try:
            response.raise_for_status()
        except requests.exceptions.HTTPError as e:
            print(e)
        with open(join('data', urlid), 'wb') as handle:
            for block in response.iter_content(1024):
                handle.write(block)
        soup = scrape_urlid(urlid)
    return soup

def get_subject_courses(urlid):
    soup = scrape_urlid(urlid)
    courses = []
    for tr in soup.find_all("tr"):
        tds = tr.find_all("td")
        try:
            m = course_code_regex.match(tds[0].text)
            c_code = m.group()
            c_urlid = tds[2].find("a")["href"]
            c_title = tds[2].find("a").text
            courses.append(Course(code=c_code, urlid=c_urlid, title=c_title))
        except (IndexError, AttributeError) as e:
            pass
    return courses

def fill_course_prereqs(course):
    soup = scrape_urlid(course.urlid)

    require = []
    recommend = []
    try:
        td_req = soup.find(text=re.compile("MUST|RECOMMEND")).parent
    except AttributeError:
        course.required = require
        course.recommended = recommend
        return course
    groups = [cl for cl in td_req.children]
    state = ""
    for s in groups:
        if re.search("MUST", str(s.encode('utf8'))):
            state = "must"
            continue
        elif re.search("RECOMMEND", str(s.encode('utf8'))):
            state = "reco"
            continue

        try:
            if state == "must":
                m = course_code_regex.search(s.text)
                code = m.group()
                title = s.text[:m.start()-1].strip()
                require.append(Course(title=title, code=code, urlid=s["href"]))
                continue
            elif state == "reco":
                m = course_code_regex.search(s.text)
                code = m.group()
                title = s.text[:m.start()-1].strip()
                recommend.append(Course(title=title, code=code, urlid=s["href"]))
                continue
        except (AttributeError) as e:
            pass
    course.required = require
    course.recommended = recommend
    return course

def create_all_courses_dictionary(courses, parent_courses=None, recurse=True):
    if parent_courses is None:
        all_courses = OrderedDict()
    else:
        all_courses = parent_courses.copy()
    for c in courses:
        if c.required is None or c.recommended is None:
            fill_course_prereqs(c)
        if c.code not in all_courses:
            all_courses[c.code] = c
        if recurse:
            req_new = [rq for rq in c.required if rq.code not in all_courses]
            rco_new = [rc for rc in c.recommended if rc.code not in all_courses]

            all_courses.update(create_all_courses_dictionary(req_new, all_courses))
            all_courses.update(create_all_courses_dictionary(rco_new, all_courses))
    return all_courses

def create_adjacency_dataframe(courses_dict):
    adj_dict = OrderedDict()
    for course_code in courses_dict:
        row = np.zeros(len(courses_dict), dtype=np.int8)
        course = courses_dict[course_code]
        for req_course in course.required:# + course.recommended:
            if req_course.code in courses_dict:
                j = courses_dict.keys().index(req_course.code)
                row[j] = 1
        adj_dict[course_code] = row
    idx = [courses_dict[c].title for c in courses_dict]
    return pd.DataFrame(adj_dict, index=idx)

def create_json_df(df, titles, cmap='Dark2'):
    unique_codes = sorted(list(set(map(lambda x: x[:4], df.columns))))
    n = len(unique_codes)
    cmap = cm.get_cmap(cmap, round(n))
    colors = [ cm.colors.rgb2hex(cmap(i)[:3]) for i in range(0, n) ]
    code_color = dict(zip(unique_codes, colors))

    df_matrix = []
    for i, indexrow in enumerate(df.iterrows()):
        index, row = indexrow
        reqs = list(row[row!=0].index)
        df_matrix.append([index, len(reqs)+1, titles[i], code_color[index[:4]],
            reqs])
    return pd.DataFrame(df_matrix, columns=['name', 'size', 'title', 'color', 'imports'])

# Earth Science
# http://www.drps.ed.ac.uk/17-18/dpt/cx_sb_easc.htm
if __name__ == '__main__':
    if os.path.isfile('adjacency_matrix.csv'):
        adj_df = pd.read_csv('adjacency_matrix.csv', index_col=0)
    else:
        courses = []
        for subj in ['easc']:
            courses += get_subject_courses('cx_sb_%s.htm' % subj)
        all_courses = create_all_courses_dictionary(courses, recurse=False)

        adj_df = create_adjacency_dataframe(all_courses)

        adj_df.to_csv('adjacency_matrix.csv')

    adj_df = create_adjacency_dataframe(all_courses)
    titles = [t[:40] for t in adj_df.index]
    titles = list(adj_df.index)#[t[:40] for t in adj_df.index]

    adj_df.index = adj_df.columns

    # To keep all courses (not just linked ones), comment from here
    new_titles = []
    cols = list(adj_df.columns)
    for code in cols:
        if adj_df.loc[:, code].sum() == 0 and adj_df.loc[code, :].sum() == 0:
            adj_df.drop([code], inplace=True)
            adj_df.drop([code], axis=1, inplace=True)
        else:
            new_titles.append(titles[cols.index(code)])
    titles = new_titles
    # To here

    df = create_json_df(adj_df, titles, 'seismic')
    df.to_json('hierarchy.json', orient='records')
