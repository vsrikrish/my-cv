"""
Filters for printing TeX and Markdown to jinja templates.
See http://flask.pocoo.org/snippets/55/ for more info.
"""

import re

LATEX_SUBS = (
    (re.compile(r'\\'), r'\\textbackslash'),
    (re.compile(r'([{}_#%&$])'), r'\\\1'),
    (re.compile(r'~'), r'\~{}'),
    (re.compile(r'\^'), r'\^{}'),
    (re.compile(r'"'), r"''"),
    (re.compile(r'\.\.\.+'), r'\\ldots'),
)


def escape_tex(value):
    """
    Escape TeX special characters
    """
    newval = value
    for pattern, replacement in LATEX_SUBS:
        newval = pattern.sub(replacement, newval)
    return newval


def select_by_attr_name(array, attr, value):
    for d in array:
        if d[attr] == value:
            return d


def sort_cast_int(array, attr, reverse=False):
    return sorted(array, key=lambda x: int(x[attr]), reverse=reverse)
