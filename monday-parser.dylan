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
 let res = tend - tstart;
 if (string[tend - 1] = ' ')
   res := res - 1;
 end;
 res;
end;
define constant $base-url = "/wiki/view.dsp?title=";
define constant $wiki-tokens
  = simple-lexical-definition
      token EOF;

      inert "([ \t\r])+";

      token LBRACKET = "\\[";
      token RBRACKET = "\\]";

      token EQUALS = "(=)+[ ]?",
        semantic-value-function: count-chars;
      token TILDES = "(~)+[ ]?",
        semantic-value-function: count-chars;
      token TICKS = "(')+",
        semantic-value-function: count-chars;

      token AMPERSAND = "&";

      token HASHMARK = "#[ ]?";
      token STAR = "*[ ]?";

      token FOUR-DASHES = "----", priority: 3;

      token PIPE = "\\|";

      token SMALLER = "<";
      token GREATER = ">";

      token WHITESPACE = " ", priority: 3;

      //token LIST-ITEM = "(\\*|#)", priority: 3;
      //token PREFORMATTED = "\n ", priority: 3;
      token NEWLINENEWLINE = "\n\n", priority: 3;

      token NEWLINE = "\n";
      //todo: ignore spaces?!

      token TEXT = "[a-zA-Z_-0-9\\.][a-zA-Z_-0-9\\. ]*",
        semantic-value-function: extract-action;

      token URL = "(http|ftp|https)://[a-zA-Z_-0-9\\.:]+",
        semantic-value-function: extract-action;
end;

define constant $wiki-productions
  = simple-grammar-productions

     production description :: false-or(<string>) => [TEXT] (data)
       TEXT;

     production wiki-page-name :: <string> => [TEXT] (data)
       TEXT;

     production myurl :: <string> => [URL] (data)
       URL;

     production external-link :: xml$<element> => [LBRACKET myurl RBRACKET] (data)
       with-xml() a(myurl, href => myurl) end;

     production external-link :: xml$<element> => [LBRACKET myurl WHITESPACE description RBRACKET] (data)
       with-xml() a(description, href => myurl) end;

     production internal-link :: xml$<element> => [LBRACKET LBRACKET wiki-page-name RBRACKET RBRACKET] (data)
       with-xml() a(wiki-page-name, href => concatenate($base-url, wiki-page-name)) end;

     production internal-link :: xml$<element> => [LBRACKET LBRACKET wiki-page-name PIPE description RBRACKET RBRACKET] (data)
       with-xml() a(description, href => concatenate($base-url, wiki-page-name)) end;

     production header :: xml$<element> => [EQUALS wiki-text EQUALS], action:
       method (p :: <simple-parser>, data, s, e)
         let heading = max(p[0], p[2]);
         unless (p[0] = p[2])
           format-out("Unbalanced number of '=' in header %s, left: %d right: %d, using %d\n",
                      p[1], p[0], p[2], heading);
         end;
         make(xml$<element>,
              name: concatenate("h", integer-to-string(heading)),
              children: p[1]);
       end;

     production unnumbered-list :: <list-node> => [STAR line] (data)
       make(<list-node>, kind: #"unnumbered", data: line);

     production numbered-list :: <list-node> => [HASHMARK line] (data)
       make(<list-node>, kind: #"numbered", data: line);

     production simple-format :: xml$<xml> => [TICKS TEXT TICKS], action:
       method (p :: <simple-parser>, data, s, e)
         let ticks = max(p[0], p[2]);
         unless (p[0] = p[2])
           format-out("Unbalanced number of ' in TICKS %s, left: %d right: %d, using %d\n",
                      p[1], p[0], p[2], ticks);
         end;
         let str = list(make(xml$<char-string>, text: p[1]));
         if (ticks = 5)
           make(xml$<element>, name: "b", children: list(make(xml$<element>, name: "i", children: str)));
         else
           let ele-name = if (ticks = 2) "i" elseif (ticks = 3) "b" end;
           if (ele-name)
             make(xml$<element>, name: ele-name, children: str);
           else
             str[0]
           end;
         end;
       end;

     production wiki-text :: <collection> => [TEXT more-wiki-text] (data)
       add!(more-wiki-text, with-xml() text(TEXT) end);

     production wiki-text :: <collection> => [internal-link more-wiki-text] (data)
       add!(more-wiki-text, internal-link);

     production wiki-text :: <collection> => [external-link more-wiki-text] (data)
       add!(more-wiki-text, external-link);

     production wiki-text :: <collection> => [simple-format more-wiki-text] (data)
       add!(more-wiki-text, simple-format);

     production more-wiki-text :: <collection> => [wiki-text] (data)
       wiki-text;

     production more-wiki-text :: <collection> => [] (data)
       #();

     production horizontal-line :: xml$<element> => [FOUR-DASHES] (data)
       with-xml() hr end;

     production preformat :: <pre-node> => [WHITESPACE TEXT] (data)
        make(<pre-node>, data: concatenate(" ", TEXT));

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
       //format-out("empty!\n");

     production lines => [preformat NEWLINE lines] (data)
       add!(data.my-real-data, preformat);

     production lines => [preformat NEWLINENEWLINE lines] (data)
       add!(data.my-real-data, make(xml$<element>, name: "p"));
       add!(data.my-real-data, preformat);

     production lines => [line NEWLINENEWLINE lines] (data)
       add!(data.my-real-data, make(xml$<element>, name: "p"));
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
  if (input[input.size - 1] ~= '\n')
    input := add!(input, '\n');
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
  //format-out("before consuming EOF at %d\n", end-position);
  simple-parser-consume-token(parser, 0, #"EOF", parser, end-position, end-position);
  //format-out("data (%d) is %=\n", data.my-real-data.size, data.my-real-data);
  let result = reverse(data.my-real-data);
  let res = make(<stretchy-vector>);
  let i :: <integer> = 0;
  while (i < result.size)
    let (value, next) = process-node(result[i], i, result);
    add!(res, value);
    i := i + next;
  end;
  reduce1(concatenate, (map(curry(as, <string>), res)));
end;

define class <parsed-node> (<object>)
  slot data, init-keyword: data:;
end;

define method as (class == <string>, object :: <parsed-node>) => (res :: <string>)
  as(<string>, object.data);
end;
define class <list-node> (<parsed-node>)
  slot list-kind :: one-of(#"numbered", #"unnumbered"), required-init-keyword: kind:;
end;
define method as (class == <string>, object :: <list-node>) => (res :: <string>)
  as(<string>, object.data[0]);
end;
define class <pre-node> (<parsed-node>)
end;

define method process-node (node :: <parsed-node>, index :: <integer>, rest-data :: <collection>) => (res :: xml$<element>, next :: <integer>)
  format-out("This should never happen\n");
end;

define method process-node (node :: <list-node>, index :: <integer>, rest-data :: <collection>) => (res :: xml$<element>, next :: <integer>)
  let list-nodes = make(<stretchy-vector>);
  let kind = node.list-kind;
  block(ret)
    for (i from index below rest-data.size)
      if (instance?(rest-data[i], <list-node>))
        if (kind == rest-data[i].list-kind)
          add!(list-nodes, rest-data[i])
        end;
      end;
      ret;
    end;
  end;

  let child = map(method(x)
                    make(xml$<element>, name: "li", children: data(x))
                  end, list-nodes);
  values(make(xml$<element>,
              name: if (kind == #"numbered") "ol" else "ul" end,
              children: child),
         list-nodes.size);
end;

define method process-node (node :: <pre-node>, index :: <integer>, rest-data :: <collection>) => (res :: xml$<element>, next :: <integer>)
  let pre-nodes = make(<stretchy-vector>);
  block(ret)
    for (i from index below rest-data.size)
      if (instance?(rest-data[i], <pre-node>))
        add!(pre-nodes, rest-data[i]);
      else
        ret;
      end;
    end;
  end;
  let child = reduce1(method(a, b) concatenate(a, "\n", b) end,
                      map(data, pre-nodes));
  let node = make(xml$<element>, name: "pre", children: list(with-xml() text(concatenate("\n", child, "\n")) end));
  values(node, size(pre-nodes));
end;

define method process-node (node :: xml$<xml>, index :: <integer>, rest-data :: <collection>) => (res :: xml$<xml>, next :: <integer>)
  values(node, 1);
end;
begin
  parse-wiki-markup(" one\n two\n three\nfoo\n");
  parse-wiki-markup(" this is pre-text\n and another line");
  format-out("RES %s\n", parse-wiki-markup("foo bar  fnord\n fooo bar   ffff\n\n* one\n* '''ttt'''"))
end;
