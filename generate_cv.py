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
TEMPLATE_DIR = "templates"
TEMP_OUTPUT_DIR = "temp_output"
DOCS_DIR = "docs"
BIB_FILE = os.path.join("my-papers", "my-papers.bib")

# Template configurations
TEMPLATES = {
    "full_cv": {
        "template": "cv.latextemplate",
        "output_tex": "Doss-Gollin-CV.tex",
        "output_pdf": "Doss-Gollin-CV.pdf",
        "copy_to_docs": True,  # This goes to GitHub Pages
    },
    "biosketch": {
        "template": "biosketch.latextemplate",
        "output_tex": "Doss-Gollin-Biosketch.tex",
        "output_pdf": "Doss-Gollin-Biosketch.pdf",
        "copy_to_docs": False,  # Keep private
    },
}


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

        # also load section data directly by key name for easier template access
        section_data = {}
        for k in config["sections"]:
            # Convert section titles to lowercase keys with underscores
            key_name = k["title"].lower().replace(" ", "_").replace("and_", "")
            section_data[key_name] = yaml.load(
                open(os.path.join(config["paths"]["yaml_path"], k["file"]), "r"),
                Loader=yaml.BaseLoader,
            )

        # combine personal, sectional data, and publication data
        self.data = {
            "person": config["person"],
            "paths": config["paths"],
            "publications": config["publications"],
            "sections": sections,
            **section_data,  # Add direct section access
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
    def jenv_tex(
        self,
    ):
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

    def copy_pdfs_to_docs(self):
        """Copy specified PDFs from temp to docs after LaTeX compilation"""
        import shutil

        for template_name, config in TEMPLATES.items():
            if config["copy_to_docs"]:
                temp_pdf = os.path.join(TEMP_OUTPUT_DIR, config["output_pdf"])
                docs_pdf = os.path.join(DOCS_DIR, config["output_pdf"])
                if os.path.exists(temp_pdf):
                    shutil.copy2(temp_pdf, docs_pdf)
                    print(f"Copied {config['output_pdf']} to docs/")


def main():
    import shutil

    my_filters = [
        filters.escape_tex,
        filters.select_by_attr_name,
        filters.sort_by_attr,
        filters.sort_first_year,
        filters.extract_year,
        filters.trim_university,
    ]

    cv = CV(CONFIG_FILE, filters=my_filters)

    # Create output directories
    if not os.path.isdir(TEMP_OUTPUT_DIR):
        os.mkdir(TEMP_OUTPUT_DIR)
    if not os.path.isdir(DOCS_DIR):
        os.mkdir(DOCS_DIR)

    # Generate all templates
    for template_name, config in TEMPLATES.items():
        print(f"Generating {template_name}...")

        # Generate TeX file in temp directory
        temp_tex_path = os.path.join(TEMP_OUTPUT_DIR, config["output_tex"])
        with open(temp_tex_path, "w") as f:
            f.write(cv.render_tex(config["template"]))

        # Copy to docs if specified
        if config["copy_to_docs"]:
            docs_tex_path = os.path.join(DOCS_DIR, config["output_tex"])
            shutil.copy2(temp_tex_path, docs_tex_path)
            print(f"  Copied {config['output_tex']} to docs/")

        print(f"  Generated {temp_tex_path}")

    # copy BiB file to temp directory
    shutil.copy2(BIB_FILE, os.path.join(TEMP_OUTPUT_DIR, "my-papers.bib"))
    print(f"  Copied my-papers.bib to {TEMP_OUTPUT_DIR}/")


if __name__ == "__main__":
    main()
