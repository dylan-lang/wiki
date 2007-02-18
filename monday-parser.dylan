module: wiki
author: Hannes Mehnert <hannes@mehnert.org>
synopsis: markup definition for dylan wiki

define function extract-action
    (token-string :: <byte-string>,
     token-start :: <integer>, 	 
     token-end :: <integer>) 	 
 => (result :: <byte-string>); 	 
  copy-sequence(token-string, start: token-start, end: token-end);
end;

define function count-chars
  (string :: <byte-string>,
   tstart :: <integer>,
   tend :: <integer>)
 => (res :: <integer>)
 tend - tstart
end;
define constant $base-url = "/wiki/view.dsp?title=";
define constant $wiki-tokens
  = simple-lexical-definition
      token EOF;

      inert "([ ])+";

      token LBRACKET = "\\[";
      token RBRACKET = "\\]";

      token EQUALS = "(=)+",
        semantic-value-function: count-chars;
      token TILDES = "(~)+",
        semantic-value-function: count-chars;
      token AMPERSAND = "&";

      token HASHMARK = "#";
      token STAR = "*";

      token FOUR-DASHES = "----", priority: 3;

      token PIPE = "\\|";

      token SMALLER = "<";
      token GREATER = ">";

      token CLIST = "(\n|\r|\r\n)(\\*|#)", priority: 3;
      token PREFORMATTED = "(\r|\n|\r\n) ", priority: 3;

      token NEWLINE = "(\n|\r|\r\n)";
      //todo: ignore spaces?!

      token TEXT = "[a-zA-Z_-0-9\\.]+",
        semantic-value-function: extract-action;

      token URL = "(http|ftp|https)://",
        semantic-value-function: extract-action;
end;

define constant $wiki-productions
  = simple-grammar-productions

     production description :: false-or(<string>) => [TEXT] (data)
       if (TEXT.size = 0) #f else TEXT end;

     production wiki-page-name :: <string> => [TEXT] (data)
       TEXT;

     production myurl :: <string> => [URL TEXT] (data)
       concatenate(URL, TEXT);

     production external-link :: xml$<element> => [LBRACKET myurl RBRACKET] (data)
       with-xml() a(myurl, href => myurl) end;

     production external-link :: xml$<element> => [LBRACKET myurl description RBRACKET] (data)
       with-xml() a(description, href => myurl) end;

     production internal-link :: xml$<element> => [LBRACKET LBRACKET wiki-page-name RBRACKET RBRACKET] (data)
       with-xml() a(wiki-page-name, href => concatenate($base-url, wiki-page-name)) end;

     production internal-link :: xml$<element> => [LBRACKET LBRACKET wiki-page-name PIPE description RBRACKET RBRACKET] (data)
       with-xml() a(description, href => concatenate($base-url, wiki-page-name)) end;

     production header :: xml$<element> => [EQUALS more-wiki-text EQUALS], action:
       method (p :: <simple-parser>, data, s, e)
         let left = p[0];
         let right = p[2];
         unless (left = right)
           format-out("Unbalanced number of '=' in header %s, left: %d right: %d, using %d\n",
                      p[1], left, right, max(left, right));
         end;
         make(xml$<element>,
              name: concatenate("h", integer-to-string(max(left, right))),
              children: p[1]);
       end;

     production unnumbered-list :: xml$<element> => [STAR list-elements] (data)
       format-out("Hit unnumbered-list %=\n", list-elements);
       make(xml$<element>, name: "ul", children: list-elements);

     production numbered-list :: xml$<element> => [HASHMARK list-elements] (data)
       make(xml$<element>, name: "ol", children: list-elements);

     production list-elements :: <collection> => [list-element more-list-elements] (data)
       format-out("Hit list-elements\n");
       add!(more-list-elements, list-element);

     production more-list-elements :: <collection> => [CLIST list-element more-list-elements] (data)
       format-out("Hit more-list-elements\n");
       add!(more-list-elements | #(), list-element);

     production more-list-elements :: <collection> => [] (data)
       format-out("Hit more-list-elements, empty\n");
       #();

     production list-element :: xml$<element> => [wiki-text] (data)
       format-out("Hit list-element %=\n", wiki-text);
       make(xml$<element>, name: "li", children: wiki-text);

     production wiki-text :: <collection> => [TEXT more-wiki-text] (data)
       add!(more-wiki-text, with-xml() text(TEXT) end);

     production wiki-text :: <collection> => [internal-link more-wiki-text] (data)
       add!(more-wiki-text, internal-link);

     production wiki-text :: <collection> => [external-link more-wiki-text] (data)
       add!(more-wiki-text, external-link);

     production more-wiki-text :: <collection> => [wiki-text] (data)
       wiki-text;

     production more-wiki-text :: <collection> => [] (data)
       #();

     production horizontal-line :: xml$<element> => [FOUR-DASHES] (data)
       with-xml() hr end;

     production preformat :: xml$<element> => [PREFORMATTED TEXT more-preformat] (data)
        make(xml$<element>,
             name: "pre",
             children: list(make(xml$<char-string>,
                                 text: concatenate("\n ", TEXT, more-preformat))));

     production more-preformat :: <string> => [TEXT more-preformat] (data)
       concatenate(" ", TEXT, more-preformat);

     production more-preformat :: <string> => [PREFORMATTED more-preformat] (data)
       concatenate("\n", more-preformat);

     production more-preformat :: <string> => [NEWLINE] (data)
       "\n";

     production line :: <collection> => [wiki-text] (data)
       wiki-text;

     production line :: <collection> => [header] (data)
       list(header);

     production line :: <collection> => [unnumbered-list] (data)
       list(unnumbered-list);

     production line :: <collection> => [numbered-list] (data)
       list(numbered-list);

     production line :: <collection> => [horizontal-line] (data)
       list(horizontal-line);

     production lines => [] (data)

     production lines => [preformat lines] (data)
       add!(data.my-real-data, preformat);

     production lines => [line NEWLINE NEWLINE lines] (data)
       add!(data.my-real-data, with-xml() p end);
       do(curry(add!, data.my-real-data), line);

     production lines => [line NEWLINE lines] (data)
       do(curry(add!, data.my-real-data), line);
end;

define constant $wiki-parser-automaton
  = simple-parser-automaton($wiki-tokens, $wiki-productions,
                            #[#"lines"]);

define function consume-token 	 
    (consumer-data,
     token-number :: <integer>,
     token-name :: <object>,
     semantic-value :: <object>,
     start-position :: <integer>,
     end-position :: <integer>)
 => ();
  //let srcloc
  //  = range-source-location(consumer-data, start-position, end-position);
  format-out("%d - %d: token %d: %= value %=\n",
             start-position,
             end-position,
             token-number,
             token-name,
             semantic-value);
  simple-parser-consume-token(consumer-data, token-number, token-name, semantic-value, start-position, end-position);
end function;

define sealed class <my-data> (<object>)
  slot my-real-data = make(<stretchy-vector>);
end;

define function parse-wiki-markup (input :: <string>)
  let rangemap = make(<source-location-rangemap>);
  rangemap-add-line(rangemap, 0, 1);
  if(input[0] = ' ')
    input := concatenate("\n", input);
  end;
  unless(input[input.size - 1] = '\n')
    input := add!(input, '\n')
  end;
  let scanner = make(<simple-lexical-scanner>,
                     definition: $wiki-tokens,
                     rangemap: rangemap);
  let data = make(<my-data>);
  let parser = make(<simple-parser>,
                    automaton: $wiki-parser-automaton,
                    start-symbol: #"lines",
                    rangemap: rangemap,
                    consumer-data: data);
  format-out("before scan-tokens, input: %s\n", input);
  scan-tokens(scanner,
              simple-parser-consume-token,
              //consume-token,
              parser,
              input,
              end: input.size,
              partial?: #f);
  let end-position = scanner.scanner-source-position;
  format-out("before consuming EOF at %d\n", end-position);
  simple-parser-consume-token(parser, 0, #"EOF", parser, end-position, end-position);
  format-out("data (%d) is %=\n", data.my-real-data.size, data.my-real-data);
  reduce1(concatenate, (map(curry(as, <string>), reverse(data.my-real-data))));
end;

begin
  parse-wiki-markup(" one\n two\n three\n foo");
  parse-wiki-markup(" this is pre-text\n and another line");
end;
