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

      token AMPERSAND = "&";

      token HASHMARK = "#";
      token STAR = "*";
      token MINUS = "-";

      token PIPE = "\\|";

      token SMALLER = "<";
      token GREATER = ">";

      token NEWLINE = "(\n|\r|\r\n)";
      //todo: ignore spaces?!

      token TEXT = "[a-zA-Z_0-9\\.]+",
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

     production header :: xml$<element> => [EQUALS wiki-text EQUALS], action:
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
       with-xml () ul { list-elements } end;

     production list-elements :: <collection> => [list-element NEWLINE more-list-elements] (data)
       format-out("Hit list-elements\n");
       add!(more-list-elements, list-element);

     production more-list-elements :: <collection> => [STAR list-element more-list-elements] (data)
       format-out("Hit more-list-elements\n");
       add!(more-list-elements | #(), list-element);

//     production more-list-elements :: <collection> => [] (data)
//       format-out("Hit more-list-elements, empty\n");
//       #();

     production list-element :: xml$<element> => [wiki-text] (data)
       format-out("Hit list-element %=\n", wiki-text);
       wiki-text;

     production wiki-text :: <collection> => [TEXT more-wiki-text] (data)
       add!(more-wiki-text, with-xml() text(TEXT) end);

     production wiki-text :: <collection> => [internal-link more-wiki-text] (data)
       add!(more-wiki-text, internal-link);

     production wiki-text :: <collection> => [external-link more-wiki-text] (data)
       add!(more-wiki-text, external-link);

     production more-wiki-text :: <collection> => [wiki-text more-wiki-text] (data)
       add!(more-wiki-text, wiki-text);

     production more-wiki-text :: <collection> => [] (data)
       #();

     production line :: <collection> => [wiki-text NEWLINE] (data)
       wiki-text;

     production line :: xml$<element> => [NEWLINE] (data)
       with-xml() p end;

     production line :: xml$<element> => [header NEWLINE] (data)
       header;

     production line :: xml$<element> => [unnumbered-list] (data)
       unnumbered-list;

     production lines => [] (data)

     production lines => [line lines] (data)
       data.my-real-data := add!(data.my-real-data, line);
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
  slot my-real-data = #();
end;

define function parse-wiki-markup (input :: <string>)
  let rangemap = make(<source-location-rangemap>);
  rangemap-add-line(rangemap, 0, 1);
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
              //simple-parser-consume-token,
              consume-token,
              parser,
              input,
              end: input.size,
              partial?: #f);
  let end-position = scanner.scanner-source-position;
  format-out("before consuming EOF at %d\n", end-position);
  simple-parser-consume-token(parser, 0, #"EOF", parser, end-position, end-position);
  format-out("data (%d) is %=\n", data.my-real-data.size, data.my-real-data);
  data.my-real-data;
end;

begin
  parse-wiki-markup("==foo==\nfoo[[bar]]");
end;
