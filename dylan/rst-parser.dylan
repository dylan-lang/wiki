Module:   %wiki
Synopsis: Parser for augmented RST markup
Author:   Carl Gay

// See README.txt for a description of the markup language we parse here.

define variable *python-executable* :: <string> = "python";
define variable *rst2html*          :: <string> = "rst2html.py";
define variable *rst2html-template* :: <string> = "rst2html-template.txt";

// These will only change when the config file is loaded.
define variable *default-markup-prefix* :: <string> = "{{";
define variable *default-markup-suffix* :: <string> = "}}";

// These are rebound when each page is parsed.
define thread variable *markup-prefix* :: <string> = *default-markup-prefix*;
define thread variable *markup-suffix* :: <string> = *default-markup-suffix*;


/// External entry point to the parser.
define generic as-html
    (page :: <object>, title :: <string>)
 => (html :: <string>);


define method as-html
    (page :: <wiki-page>, title :: <string>)
 => (html :: <string>)
  rst2html(map(as-rst, page.page-parsed-source))
end method as-html;

define method as-html
    (source :: <string>, title :: <string>)
 => (html :: <string>)
  rst2html(map(as-rst, parse-wiki-markup(source, title)))
end;


/// Parse one unit of wiki markup.  Normally that means a page.  When
/// one page is included in another, the included page is not part of
/// the "parent" unit; it comprises its own unit.  This is important
/// mainly to define the way that the {{escape: <pre> <post>}} markup
/// is processed.  It applies to a single "markup unit" and the escape
/// affixes are restored to their previous values when the parser is
/// done processing a given unit.
///
/// Values:
///   chunks - A sequence of strings (RST source) and <wiki-reference>s.
///
define function parse-wiki-markup
    (markup :: <string>, title :: <string>)
 => (chunks :: <sequence>)
  let chunks :: <sequence> = make(<stretchy-vector>);
  // Save the two bindings and restore them to their original
  // values when this markup unit is done being processed.
  dynamic-bind (*markup-prefix* = *default-markup-prefix*,
                *markup-suffix* = *default-markup-suffix*)
    iterate loop (start :: <integer> = 0)
      if (start < markup.size)
        let markup-bpos = find-substring(markup, *markup-prefix*, start: start);
        if (~markup-bpos)
          add!(chunks, slice(markup, start, #f));
        else
          add!(chunks, slice(markup, start, markup-bpos));
          // Save markup suffix size.  It may change in parse-markup-element
          // but the suffix in effect when the prefix was parsed must be used
          // for parsing this element.
          let markup-suffix-size = *markup-suffix*.size;
          let (chunk, epos)
            = parse-markup-element(markup, markup-bpos + *markup-prefix*.size);
          add!(chunks, chunk);
          loop(epos + markup-suffix-size);
        end if;
      end if;
    end iterate;
  end;
  chunks
end function parse-wiki-markup;

/// Parse one markup element delimited by *markup-prefix* and *markup-suffix*.
/// Arguments:
///   markup-text - The entire text being parsed.
///   bpos - The index within 'markup-text' following '*markup-prefix*'.
/// Values:
///   chunk - The string or <wiki-reference> resulting from parsing the element.
///     If a string, then it may contain RST markup.  If a <wiki-reference>,
///     then the reference may contain RST markup when rendered as a string.
///   epos - The index within 'markup-text' of *markup-suffix*.
/// Signals:
///   <parse-error>  TODO:
///
define function parse-markup-element
    (markup-text :: <string>, bpos :: <integer>)
 => (chunk :: type-union(<string>, <wiki-reference>), epos :: <integer>)
  let epos = find-substring(markup-text, *markup-suffix*, start: bpos);
  if (epos)
    let tokens = tokenize(slice(markup-text, bpos, epos));
    values(iff(empty?(tokens),
               "",
               apply(handle-markup, tokens.head, tokens.tail)),
           epos)
  else
    // An unmatched {{ will show up verbatim in the output.  Reasonable?
    values(*markup-prefix*, bpos + *markup-prefix*.size)
  end
end function parse-markup-element;

/// Given the text between '*markup-prefix*' and '*markup-suffix*',
/// return a list of tokens.  e.g.,
///   {{user: joe, "blah"}} => #(#"user", "joe", "blah")
///
define function tokenize
    (text :: <string>) => (tokens :: <list>)
  let end-delims = make(<byte-string>, size: 3);
  end-delims[0] := ',';
  end-delims[1] := *markup-suffix*[0];
  end-delims[2] := ':';
  iterate loop (bpos :: <integer> = 0, tokens :: <list> = #())
    if (~empty?(tokens) & tokens.head = "")
      tokens := tokens.tail;
    end;
    let bpos = skip-whitespace(text, bpos);
    if (bpos = text.size)  // nothing left to parse
      reverse!(tokens)
    else
      let char1 = text[bpos];
      if (char1 = '"')
        let (token, epos) = parse-string-token(text, bpos + 1, "\"");
        loop(epos, pair(token, tokens))
      elseif (char1 = '\'')
        let (token, epos) = parse-string-token(text, bpos + 1, "'");
        loop(epos, pair(token, tokens))
      else
        let (token, epos, delim) = parse-string-token(text, bpos, end-delims);
        // Change any token that ends with colon into a symbol. (This means
        // page titles that end with or contain a colon must be quoted.)
        iff(delim = ':',
            loop(epos, pair(as(<symbol>, token), tokens)),
            loop(epos, pair(token, tokens)))
          
      end
    end
  end
end function tokenize;

define function skip-whitespace
    (text :: <string>, bpos :: <integer>) => (epos :: <integer>)
  let len :: <integer> = text.size;
  iterate loop (i = bpos)
    if (i >= len)
      len
    else
      let ch :: <character> = text[i];
      iff(ch == ' ' | ch == '\t' | ch == '\n',
          loop(i + 1),
          i)
    end
  end
end function skip-whitespace;

/// Find a token in 'text' that starts at 'bpos' and ends with one of
/// the characters in 'end-delims' or the end of 'text'.
/// Arguments:
///   text - The string being parsed.
///   bpos - Where to start parsing the token.  This is the position following
///       the start delimeter, if any.
///   end-delims - The collection of characters that mark the end of the token.
/// Values:
///   token - A non-empty string.
///   epos - The index in 'text' following the end delimeter.
///   end-delim - The actual end delimeter character that terminated the token,
///       or '\0' if the end of 'text' was found.
///
define function parse-string-token
    (text :: <string>, bpos :: <integer>, end-delims :: <string>)
 => (token :: <string>, epos :: <integer>, end-delim :: <character>)
  let len :: <integer> = text.size;
  iterate loop (i = bpos)
    case
      i = len =>
        values(strip(slice(text, bpos, #f)), i, '\0');
      member?(text[i], end-delims) =>
        let tok = slice(text, bpos, i);
        let delim = text[i];
        if (delim ~= '"' & delim ~= '\'')
          tok := strip(tok);
        end;
        values(tok, i + 1, text[i]);
      otherwise =>
        loop(i + 1)
    end
  end
end function parse-string-token;

/// This generic allows client libraries to define their own markup
/// tags, similar to {{page: foo}}.  The method dispatches on the
/// keyword following {{.
/// (Note: This doesn't allow clients any way to override handling for
/// existing keywords, which might be nice.)
///
define open generic handle-markup
    (token :: <object>, #rest more-tokens)
 => (chunk :: type-union(<string>, <wiki-reference>));


/// Give some warning about invalid markup keywords.
define method handle-markup
    (token :: <symbol>, #rest more-tokens) => (rst :: <string>)
  // TODO: have a config setting that determines whether to err or
  // include debug markup here.
  format-to-string("INVALID WIKI MARKUP KEYWORD: %s:", token)
end;


/// This method handles the shorthand cases of {{Page Title}} or
/// {{Page Title, Text to show}}.  It simply converts it into the
/// canonical form: {{page: Page, text: Text}} and passes it on.
///
define method handle-markup
    (token :: <string>, #rest more-tokens)
 => (rst :: type-union(<string>, <wiki-reference>))
  apply(handle-markup, #"page", token,
        select (more-tokens.size)
          0 => list(#"text", token);
          1 => list(#"text", more-tokens[0]);
          otherwise => more-tokens;
        end)
end method handle-markup;

/// Make a <wiki-reference> to the page with the given title.
/// This handles the forms {{page: foo}}, {{page: foo, bar}},
/// and {{page: foo, text: bar}}.
///
define method handle-markup
    (token == #"page", #rest more-tokens) => (ref :: <page-reference>)
  let (title, keyword, text) = apply(values, more-tokens);
  let text = text | keyword | title;
  make(<page-reference>,
       name: title,
       text: text,
       target: find-page(title))  // may be #f
end method handle-markup;

/// Make an RST link to the user with the given name.
/// This handles the forms {{user: foo}}, {{user: foo, bar}}, and
/// {{user: foo, text: bar}}.
///
define method handle-markup
    (token == #"user", #rest more-tokens) => (ref :: <user-reference>)
  let (name, keyword, text) = apply(values, more-tokens);
  let text = text | keyword | name;
  make(<user-reference>,
       name: name,
       text: text,
       target: find-user(name)) // may be #f
end method handle-markup;

/// Make an RST link to the group with the given name.
/// This handles the forms {{group: foo}}, {{group: foo, bar}},
/// and {{group: foo, text: bar}}.
///
define method handle-markup
    (token == #"group", #rest more-tokens) => (ref :: <group-reference>)
  let (name, keyword, text) = apply(values, more-tokens);
  let text = text | keyword | name;
  make(<group-reference>,
       name: name,
       text: text,
       target: find-group(name)) // may be #f
end method handle-markup;

/// Handle markup of the form {{escape: "[[" "]]"}}
///
define method handle-markup
    (token == #"escape", #rest more-tokens) => (rst :: <string>)
  if (more-tokens.size = 2)
    *markup-prefix* := more-tokens[0];
    *markup-suffix* := more-tokens[1];
    ""
  else
    "INVALID 'escape:' WIKI MARKUP"
  end
end method handle-markup;

/// Handle markup of the form {{include: "Page"}}
///
define method handle-markup
    (token == #"include", #rest more-tokens) => (rst :: <string>)
  if (empty?(more-tokens))
    "INVALID 'include:' WIKI MARKUP"
  else
    let title = more-tokens[0];
    let page = find-page(title);
    if (page)
      // Undo any change to the markup suffixes done via the "escape"
      // directive in the containing page.
      dynamic-bind (*markup-prefix* = *default-markup-prefix*,
                    *markup-suffix* = *default-markup-suffix*)
        join(parse-wiki-markup(page.page-parsed-source, page.page-title), "",
             key: as-rst)
      end
    else
      // Display the standard markup for a not-yet-written page, with
      // <hr>s around it.
      concatenate("\n****\n\n",
                  handle-markup(#"page", title),
                  "\n\n****\n")
    end
  end
end method handle-markup;


define function rst2html
    (rst-chunks :: <sequence>) => (html :: <string>)
  let command = format-to-string("%s %s --template %s --no-doc-title --link-stylesheet",
                                 *python-executable*, *rst2html*, *rst2html-template*);
  let html = "";
  let (error, process, stdin, stdout, stderr) = #f;
  block ()
    log-debug("running rst2html");
    let (exit-code, signal, child, in, out, err)
      = run-application(command,
                        asynchronous?: #t,
                        input: #"stream", output: #"stream", error: #"stream");
    log-debug("ran rst2html");
    process := child;
    stdin := in;
    stdout := out;
    stderr := err;
    for (chunk in rst-chunks)
      write(stdin, as-rst(chunk));
    end;
    force-output(stdin);
    close(stdin);
    html := read-to-end(stdout);
    error := read-to-end(stderr);
    log-debug("read stderr %d bytes", error.size);
  cleanup
    if (process)
      ignore-errors(close(stdin, abort?: #t));
      ignore-errors(close(stdout, abort?: #t));
      ignore-errors(close(stderr, abort?: #t));
      wait-for-application-process(process);   // prevent zombies
    end;
  end block;
  if (~empty?(error))
    log-error("stderr: %s", error);
  end;
  html
end function rst2html;


