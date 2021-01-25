import os
import sys
import re

import yaml  # parse YAML files
import jinja2  # templating for CV

# add parent directory to system path
try:
    fileroot = os.path.dirname(os.path.realpath(__file__))
except NameError:  # We are the main py2exe script, not a module
    fileroot = os.path.dirname(os.path.realpath(os.getcwd()))
print(fileroot)
sys.path.append(fileroot)
import filters  # filters for Jinja

class CV(object):
    """
    Build CV in LaTeX and Markdown formats from YAML and BiBTeX inputs
    """

    def __init__(self, config_file, filters=None, templates=None):

        self.filters = filters
        # read config file
        with open(config_file, 'r') as f:
            config = yaml.load(f, Loader=yaml.BaseLoader)

        # read in section data files
        sections = [
            {'title': k['title'], 'entries': yaml.load(open(os.path.join(config['paths']['yaml_path'], k['file']), 'r'), Loader=yaml.BaseLoader)}
            for k in config['sections']
        ]

        # combine personal, sectional data, and publication data
        self.data = {'person': config['person'], 'paths': config['paths'], 'publications': config['publications'], 'sections': sections}

        # load templates
        templates = {} if templates is None else templates
        self.loader = jinja2.loaders.DictLoader(templates)

    @property
    def jenv_md(self):
        """
        Set up HTML/Markdown Jinja environment
        """
        loader = jinja2.loaders.ChoiceLoader([
            self.loader,
            jinja2.FileSystemLoader(
                os.path.join(os.path.dirname(os.path.realpath(__file__)), 'templates'))
        ])
        jenv = jinja2.Environment(loader=loader)
        for f in self.filters:
            jenv.filters[f.__name__] = f
        return jenv

    @property
    def jenv_tex(self,):
        """
        Set up TeX environment
        """
        try:
            fileroot = os,path.dirname(os.path.realpath(__file__))
        except NameError:  # We are the main py2exe script, not a module
            fileroot = os.path.dirname(os.path.realpath(os.getcwd()))
        loader = jinja2.ChoiceLoader([
            self.loader,
            jinja2.FileSystemLoader(
                os.path.join(fileroot, 'templates'))
        ])
        jenv = jinja2.Environment(loader=loader)
        # define new delimiters to avoid TeX conflicts
        jenv.block_start_string = '((*'
        jenv.block_end_string = '*))'
        jenv.variable_start_string = '((('
        jenv.variable_end_string = ')))'
        jenv.comment_start_string = '((='
        jenv.comment_end_string = '=))'
        for f in self.filters:
            jenv.filters[f.__name__] = f
        return jenv

    def render_tex(self, template, **kwargs):
        return self.jenv_tex.get_template(template).render(
            data=self.data, **kwargs)


my_filters = [
    filters.escape_tex,
    filters.select_by_attr_name,
    filters.sort_by_attr,
    filters.sort_first_year
]
cv = CV('_config.yml', filters=my_filters)
with open('Srikrishnan-CV.tex', 'w') as f:
    f.write(cv.render_tex(os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), 'templates', 'cv.tex')))
