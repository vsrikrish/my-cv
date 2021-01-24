"""
Filters for printing TeX and Markdown to jinja templates.
See http://flask.pocoo.org/snippets/55/ for more info.
"""

import re

LATEX_SUBS = (
    (re.compile(r'\\'), r'\\textbackslash'),
    (re.compile(r'([#%&{}])'), r'\\\1'),
    (re.compile(r'~'), r'\~{}'),
    (re.compile(r'\^'), r'\^{}'),
    (re.compile(r'^"'), r"``"),
    (re.compile(r'"$'), r"''"),
    (re.compile(r'\.\.\.+'), r'\\ldots')
)


def escape_tex(value):
    """
    Escape TeX special characters
    """
    newval = value
    for pattern, replacement in LATEX_SUBS:
        newval = pattern.sub(replacement, newval, re.MULTILINE)
    return newval


def select_by_attr_name(array, attr, value):
    for d in array:
        if d[attr] == value:
            return d


def sort_by_attr(array, attr, reverse=False):
    if type(attr) is list:
        sorted_array = sorted(array, key=lambda x: tuple(str(x[a]) for a in attr), reverse=reverse)
    else:
        sorted_array = sorted(array, key=lambda x: str(x[a] for a in attr), reverse=reverse)
    return sorted_array


def sort_first_year(array, attr, reverse=False):
    return sorted(array, key=lambda x: int(re.findall(r'^\d{4}', str(x[attr]))[0]), reverse=reverse)
