Module: wiki-test-suite
Synopsis: Tests for the RST+markup parser
Author: Carl Gay

define suite rst-parser-test-suite ()
  test test-parse-string-token;
  test test-skip-whitespace;
  test test-tokenize; 
  test test-parse-markup-element;
  test test-parse-wiki-markup;
end;

define test test-skip-whitespace ()
  check-equal("normal skip", skip-whitespace(" \t\nxyz", 0), 3);
  check-equal("no movement", skip-whitespace(" \t\nxyz", 3), 3);
  check-equal("at end", skip-whitespace(" \t\nxyz", 6), 6);
end;

define test test-parse-string-token ()
  check-equal("double quote", parse-string-token("\"foo\" bar", 1, "\""), "foo");
  check-equal("single quote 1", parse-string-token("'foo' bar", 1, "'"), "foo");
  check-equal("single quote 2", parse-string-token("'f\"o' bar", 1, "'"), "f\"o");

  let (tok, index, delim) = parse-string-token("foo: bar", 0, ":,");
  check-equal("tok", tok, "foo");
  check-equal("index", index, 4);
  check-equal("delim", delim, ':');

  check-equal("not quoted", parse-string-token("foo, bar", 0, ","), "foo");
  check-equal("trim trailing whitespace",
              parse-string-token("foo , bar", 0, ","), "foo");
end;

define test test-tokenize ()
  check-equal("tokenize",
              tokenize("a, b: \"c\" , \"d:\", e f , 'g '"),
              #("a", b:, "c", "d:", "e f", "g "));
end;

define test test-parse-markup-element ()
end;

define test test-parse-wiki-markup ()
end;

