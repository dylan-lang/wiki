module: wiki

define variable *markup-method* = parse-wiki-markup;


define test newline ()
  check-equal("Newline inserts paragraph", "foo<P/>bar", *markup-method*("foo\n\nbar\n"));
end;

define test internal-link ()
  check-equal("Internal link",
              "<A href=\"/wiki/view.dsp?title=foo\">foo</A>",
              *markup-method*("[[foo]]"));
end;

define test external-link ()
  check-equal("External link",
              "<A href=\"http://www.ccc.de\">http://www.ccc.de</A>",
              *markup-method*("[http://www.ccc.de]"));
end;

define test external-link-with-label ()
  check-equal("External Link with label",
              "<A href=\"http://www.ccc.de\">foobar</A>",
              *markup-method*("[http://www.ccc.de foobar]"));
end;

define test heading2 ()
  check-equal("Heading 2", "<h2>foo</h2>", *markup-method*("==foo=="));
end;

define test heading3 ()
  check-equal("Heading 3", "<h3>fooo</h3>", *markup-method*("===fooo==="));
end;

define test heading4 ()
  check-equal("Heading 4", "<h4>foooo</h4>", *markup-method*("==== foooo ===="));
end;

define test heading5 ()
  check-equal("Heading 5", "<h5>fooooo</h5>", *markup-method*("===== fooooo ====="));
end;

define test heading54 ()
  check-equal("Heading 54", "<h5>fooooo</h5>", *markup-method*("===== fooooo ===="));
end;

define test unnumbered-list ()
  check-equal("Unnumbered list",
              "<ul><li>one</li><li>two</li><li>three</li></ul>",
              *markup-method*("* one\n* two\n* three\n"));
end;

define test numbered-list ()
  check-equal("Numbered list",
              "<ol><li>one</li><li>two</li><li>three</li></ol>",
              *markup-method*("# one\n# two\n# three\n"));
end;

define test nested-list ()
  check-equal("Nested list",
              "<ul><li>one</li><li>two</li><ul><li>two and a half</li></ul><li>three</li></ul>",
              *markup-method*("* one\n* two\n** two and a half\n* three\n"));
end;

define test horizontal-line ()
  check-equal("Horizontal line", "<hr/>", *markup-method*("----"));
end;

define test nowiki-markup ()
  check-equal("Nowiki markup",
              "foo [http://foo]",
              *markup-method*("<nowiki>foo [http://foo]</nowiki>"));
end;

define test pre-formatted ()
  check-equal("Pre-formatted text",
              "<pre>\n this is pre-text\n and another line\n</pre>",
              *markup-method*(" this is pre-text\n and another line"));

end;

define suite parser-suite ()
  test newline;
  test internal-link;
  test external-link;
  test external-link-with-label;
  test heading2;
  test heading3;
  test heading4;
  test heading5;
  test heading54;
  test unnumbered-list;
  test numbered-list;
  test nested-list;
  test horizontal-line;
  //test nowiki-markup;
  test pre-formatted;
end;

begin
  run-test-application(parser-suite)
end;

