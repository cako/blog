---
layout: post
title:  "Hierarchical Edge Bundling for Courses"
date:   2018-07-15
categories: python D3.js dataviz
---

![Subset of courses](https://s3.eu-west-2.amazonaws.com/cdacosta-londonbucket/github/easc_courses.png)

[Hierarchical edge bundling](https://dx.doi.org/10.1109/TVCG.2006.147) is a method for visualizing hierarchical relations between items, represented as directed graphs.
It has been used to show call graphs from a software system and dependencies between classes (in the object-oriented sense).
The latter was implemented using [D3.js](https://d3js.org/) by Mike Bostock.

I have taken [Mike's work](https://bl.ocks.org/mbostock/1044242) and used it to visualize course pre-requisites from the University of Edinburgh.
Mike's code takes a JSON file written in a specific way.
In the file **[`parse-df.py`](https://github.com/cako/blog/blob/master/codes/2018-07-15-hierarchical-courses/parse-drps.py)** I download the information from the University websites, and parse them to create the required JSON.

The image above was created from looking only at the courses which require or are required by others.
Have a play with here:

<center>
<b><a href="http://bl.ocks.org/cako/raw/f551c5c9f86d30d2efde0a16edcc2c43/">Click here for an interactive display of <i>connected</i> Earth Science courses</a></b>
</center>

Click on the nodes to display its links.
Red link means the source node course requires the target node course
Green link means it is required by the target node.
Hover for more information, double-click to be taken to the course webpage.

I have also created one with all courses in the Earth Sciences subject.
<center>
<b><a href="http://bl.ocks.org/cako/raw/2ddb8042296d8fbc24dc7ccf1afc4ede/">Click here for an interactive display of <i>all</i> Earth Science courses</a></b>
</center>

It looks like this:
![All courses](https://s3.eu-west-2.amazonaws.com/cdacosta-londonbucket/github/easc_all_courses.gif)

You can also play with it locally.
Download **[all the codes](https://github.com/cako/blog/blob/master/codes/2018-07-15-hierarchical-courses/)**, and run a simple server on the downloaded folder with:

{% highlight bash %}
python2 -m SimpleHTTPServer
{% endhighlight %}

Open a browser and head to `http://localhost:8000/`.
If you want to try for other subject codes, delete the old `adjacency_matrix.csv`, modify **[`parse-df.py`](https://github.com/cako/blog/blob/master/codes/2018-07-15-hierarchical-courses/parse-drps.py)** by putting the new subject courses and re-run it.

#### Further reading
* Play with the source code from the [connected subset](http://bl.ocks.org/cako/f551c5c9f86d30d2efde0a16edcc2c43/) and [all courses](http://bl.ocks.org/cako/raw/2ddb8042296d8fbc24dc7ccf1afc4ede/)

* Another, very nice [tool for hierarchical edge bundling in JavaScript](https://github.com/mbostock/dependency-tree) from Mike Bostock

* [D3.js documentation](https://d3js.org/)

* [Web scraping with `requests` and `BeautifulSoup`](https://www.digitalocean.com/community/tutorials/how-to-work-with-web-data-using-requests-and-beautiful-soup-with-python-3)
