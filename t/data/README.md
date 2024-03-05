# Test data

## CommonMark JSON test suites

The `cmark.tests.json` and `github.tests.json` files are licenced under
[![CC BY-SA licence](cc-by-sa.png)](http://creativecommons.org/licenses/by-sa/4.0/).

Their source can be found respectively at the
[CommonMark Spec website](https://spec.commonmark.org/) and the
[GitHub Flavored Markdown Spec website](https://github.github.com/gfm/).

The JSON files are generated with:

    third_party/commonmark-spec/test/spec_tests.py --dump-tests --spec third_party/commonmark-spec/spec.txt > t/data/cmark.tests.json
    third_party/cmark-gfm/test/spec_tests.py --dump-tests --spec third_party/cmark-gfm/test/spec.txt > t/data/github.tests.json

But note that there are currently some bugs in the generation of the file for
the GitHub test suite, with some tests being empty or missing.
