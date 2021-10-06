"""
This script builds the CV file from a template
"""

import os
import sys
import re
import filters  # filters for Jinja
import jinja2
import yaml

# definitions
CONFIG_FILE = "_config.yml"
TEMPLATE_FILE = "cv.latextemplate"  # NOT relative
TEMPLATE_DIR = "templates"
OUTPUT_TEX = os.path.join("docs", "Doss-Gollin-CV.tex")


class CV(object):
    """
    Build CV in LaTeX and Markdown formats from YAML and BiBTeX inputs
    """

    def __init__(self, config_file, filters=None, templates=None):

        self.filters = filters
        # read config file
        with open(config_file, "r") as f:
            config = yaml.load(f, Loader=yaml.BaseLoader)

        # read in section data files
        sections = [
            {
                "title": k["title"],
                "entries": yaml.load(
                    open(os.path.join(config["paths"]["yaml_path"], k["file"]), "r"),
                    Loader=yaml.BaseLoader,
                ),
            }
            for k in config["sections"]
        ]

        # combine personal, sectional data, and publication data
        self.data = {
            "person": config["person"],
            "paths": config["paths"],
            "publications": config["publications"],
            "sections": sections,
        }

        # load templates
        templates = {} if templates is None else templates
        self.loader = jinja2.loaders.DictLoader(templates)

    @property
    def jenv_md(self):
        """
        Set up HTML/Markdown Jinja environment
        """
        loader = jinja2.loaders.ChoiceLoader(
            [
                self.loader,
                jinja2.FileSystemLoader(
                    os.path.join(
                        os.path.dirname(os.path.realpath(__file__)), "templates"
                    )
                ),
            ]
        )
        jenv = jinja2.Environment(loader=loader)
        for f in self.filters:
            jenv.filters[f.__name__] = f
        return jenv

    @property
    def jenv_tex(self,):
        """
        Set up TeX environment
        """
        loader = jinja2.ChoiceLoader(
            [self.loader, jinja2.FileSystemLoader(TEMPLATE_DIR)]
        )
        jenv = jinja2.Environment(loader=loader)
        # define new delimiters to avoid TeX conflicts
        jenv.block_start_string = "((*"
        jenv.block_end_string = "*))"
        jenv.variable_start_string = "((("
        jenv.variable_end_string = ")))"
        jenv.comment_start_string = "((="
        jenv.comment_end_string = "=))"
        for f in self.filters:
            jenv.filters[f.__name__] = f
        return jenv

    def render_tex(self, template, **kwargs):
        return self.jenv_tex.get_template(template).render(data=self.data, **kwargs)


def main():

    my_filters = [
        filters.escape_tex,
        filters.select_by_attr_name,
        filters.sort_by_attr,
        filters.sort_first_year,
    ]

    cv = CV(CONFIG_FILE, filters=my_filters)

    if not os.path.isdir("docs"):
        os.mkdir("docs")

    with open(OUTPUT_TEX, "w") as f:
        f.write(cv.render_tex(TEMPLATE_FILE))


if __name__ == "__main__":
    main()

