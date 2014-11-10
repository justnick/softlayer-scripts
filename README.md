softlayer-scripts
=================

A bunch of scripts helping to automate some basic cloud management tasks in IBM Softlayer

### create_image_rest_api.sh



create_image_rest_api.sh is utilizing the Softlayer RESTful API to create a so called "Image Template" for particular Virtual Server (VS) / Cloud Computing Instance (CCI) ID.

More about the Softlayer APIs and REST in particular can be found on the following links:

[http://sldn.softlayer.com/] (http://sldn.softlayer.com/)

[http://sldn.softlayer.com/article/rest] (http://sldn.softlayer.com/article/rest)

[http://sldn.softlayer.com/blog/klaude/Time-REST-Everyone] (http://sldn.softlayer.com/blog/klaude/Time-REST-Everyone)

 
#### Usage:
```bash
./create_image_rest_api.sh <123456>
```

Note:
* You should add your username and API key in the SLAPI_VARS file.
* You should give your CCI ID as argument to the script.

### create_image_sl_py.sh

create_image_sl_py.sh is practically the same as create_image_rest_api.sh but it's using the Softlayer Python API and client instead. In fact create_image_rest_api.sh was created because the Python version of CentOS 5.x is too old and sl client install fails.

In order to use this script you should install sl python client first. Installation instructions and more about the API itself can be found in their  [repo here] (https://github.com/softlayer/softlayer-python)
