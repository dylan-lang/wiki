Module: wiki
Synopsis: An ad-hoc parser for wiki markup
Author: Carl Gay
Copyright: This code is in the public domain.


define variable *wiki-link-url* = "/wiki/view.dsp?title=";

// This table maps the leading character of any markup that can occur
// top-level (i.e., anywhere in the wiki page) to a function that
// parses that kind of markup.  Once we've dispatched to the correct
// parser based on the first character, that parser might dispatch
// further based on subsequent characters.
define table $markup-top-level
  = { '[' => parse-link,
      // TODO: '/' => parse-comment,
      '\n' => parse-newline,
      '<' => parse-less-than,
      '&' => parse-ampersand
      };

// Markup that may occur after a newline (plus optional whitespace) has
// just been seen.
define table $markup-after-newline
  = { '=' => parse-header,
      '#' => parse-numbered-list,
      '*' => parse-bulleted-list,
      '|' => parse-table,
      '-' => parse-horizontal-line,
      '\n' => parse-newline-newline
      };

define method wiki-markup-to-html
    (markup :: <string>, #key start :: <integer> = 0)
 => (html :: <string>)
  with-output-to-string (html-stream)
    parse-markup(html-stream, markup, start, $markup-top-level);
  end;
end;

define method parse-markup
    (out :: <stream>, markup :: <string>, start :: <integer>, parser-table :: <table>)
  let leading-chars = table-keys(parser-table);
  iterate loop (start :: <integer> = start)
    // find first occurrance of a "markup leading character"...
    if (start < markup.size)
      let markup-index = find(markup, rcurry(member?, leading-chars), start: start);
      //log-debug("start = %s, markup-index = %s", start, markup-index);
      if (~markup-index)
        write(out, markup, start: start);
      else
        write(out, markup, start: start, end: markup-index);
        let dispatch-char = markup[markup-index];
        let parser = parser-table[dispatch-char];
        let end-pos = parser(out, markup, markup-index);
        if (end-pos)
          // successful parse
          loop(end-pos);
        else
          // unsuccessful parse
          write-element(out, dispatch-char);
          loop(markup-index + 1);
        end;
      end if;
    end if;
  end iterate;
end method parse-markup;

define method parse-table
    (out :: <stream>, markup :: <string>, start :: <integer>)
 => (end-pos :: false-or(<integer>))
  // TODO
end;

// The parser has just encountered a newline in the markup...
define method parse-newline
    (out :: <stream>, markup :: <string>, start :: <integer>)
 => (end-pos :: false-or(<integer>))
  let index = find(markup, method (c) ~member?(c, " \t\r") end, start: start + 1);
  if (index)
    let parser = element($markup-after-newline, markup[index], default: #f);
    if (parser)
      parser(out, markup, index)
    elseif (start + 1 < markup.size & markup[start + 1] == ' ')
      // lines preceded by space are preformatted...
      // Find next line with no leading whitespace...
      let (epos, #rest xs) = regexp-position(markup, "\n\\S", start: start + 1) | markup.size;
      write(out, "<pre>");
      write(out, markup, start: start, end: epos);
      write(out, "</pre>");
      epos
    end
  end 	// note returning #f or end-pos of parser
end method parse-newline;

define method parse-newline-newline
    (out :: <stream>, markup :: <string>, start :: <integer>)
 => (end-pos :: false-or(<integer>))
  write(out, "<p/>\n");
  // Note that this leaves the SECOND newline in the input stream.
  // This is kind of a kludge to make sure that if the following
  // markup must be preceded by a newline it'll still parse correctly.
  // Otherwise we'd return start + 1 here.
  start
end method parse-newline-newline;

define method find
    (text :: <string>, fun :: <function>,
     #key start :: <integer> = 0, end: epos)
 => (pos :: false-or(<integer>))
  block (return)
    for (i :: <integer> from start below epos | text.size)
      if (fun(text[i]))
        return(i);
      end;
    end;
  end;
end method find;

define method find
    (text :: <string>, char :: <character>,
     #key start :: <integer> = 0, end: epos = #f)
 => (pos :: false-or(<integer>))
  find(text, curry(\==, char), start: start, end: epos)
end;

// Parse == heading == markup
define method parse-header
    (out :: <stream>, markup :: <string>, start :: <integer>)
 => (end-pos :: false-or(<integer>))
  let newline = find(markup, '\n', start: start) | markup.size;
  let (#rest idxs) = regexp-position(markup, "(==+)([^=\n]+)(==+)\\s*(\n|$)",
                                     start: start, end: newline);
  if (idxs.size > 1)
    let tag = copy-sequence(markup, start: idxs[2], end: idxs[3]);
    let header = copy-sequence(markup, start: idxs[4], end: idxs[5]);
    format(out, "<h%d>%s</h%d>\n", tag.size, header, tag.size);
    idxs[7]
  end
end method parse-header;

// Parse [[wiki-title]] or [url|label] markup.
// @param start points to the initial '[' char.
define method parse-link
    (out :: <stream>, markup :: <string>, start :: <integer>)
 => (end-pos :: false-or(<integer>))
  // links can't span multiple lines
  let close = find(markup, method (x) x == ']' | x == '\n' end, start: start);
  if (close & markup[close] == ']')
    let wiki-link? = (markup[start + 1] == '[');
    if (wiki-link?)
      close := close + 1;
      if (markup.size <= close | markup[close] ~== ']')
        note-form-message("The link %s is invalid wiki markup.",
                          copy-sequence(markup, start: start, end: close));
        close := close - 1;
      end;
      let title = copy-sequence(markup, start: start + 2, end: close - 1);
      format(out, "<a href=\"%s%s\">%s%s</a>",
             *wiki-link-url*,
             title,
             if (page-exists?(title)) "" else "[?]" end,
             title);
    else
      let bar = find(markup, '|', start: start, end: close);
      let url = copy-sequence(markup, start: start + 1, end: bar | close);
      let label = bar & copy-sequence(markup, start: bar + 1, end: close);
      format(out, "<a href=\"%s\">%s</a>", url, label | url);
    end if;
  end if;
  close + 1
end method parse-link;

define method parse-bulleted-list
    (out :: <stream>, markup :: <string>, start :: <integer>)
 => (end-pos :: false-or(<integer>))
  generate-list(out, markup, start, '*', "ul")
end;

define method parse-numbered-list
    (out :: <stream>, markup :: <string>, start :: <integer>)
 => (end-pos :: false-or(<integer>))
  generate-list(out, markup, start, '#', "ol")
end;

define method generate-list
    (stream, markup, start, bullet-char, tag)
 => (end-pos :: false-or(<integer>))
  let regex1 = format-to-string("\n\\s*[^%s]", bullet-char);
  let (list-end, #rest xs) = regexp-position(markup, regex1, start: start);
  let lines = split(copy-sequence(markup,
                                  start: start,
                                  end: list-end | markup.size),
                    separator: "\n", trim?: #t);
  write(stream, "<p>\n");
  let depth :: <integer> = 0;
  let regex2 = format-to-string("^\\s*([%s]+)", bullet-char);
  for (line in lines)
    let (#rest indexes) = regexp-position(line, regex2);
    if (indexes.size > 1)
      let bullet-start = indexes[2];
      let bullet-end = indexes[3];
      let num-bullets = bullet-end - bullet-start;
      let item-html = wiki-markup-to-html(line, start: bullet-end);
      case
        num-bullets < depth =>
          format(stream, "</%s>\n<li>%s</li>", tag, item-html);
          dec!(depth);
        num-bullets = depth =>
          format(stream, "<li>%s</li>\n", item-html);
        num-bullets > depth =>
          format(stream, "<%s>\n<li>%s</li>", tag, item-html);
          inc!(depth);
      end case;
    end if;
  end for;
  for (i from 0 below depth)
    format(stream, "</%s>\n", tag);
  end;
  write(stream, "</p>\n");
  list-end | markup.size
end method generate-list;

define method parse-horizontal-line
    (out :: <stream>, markup :: <string>, start :: <integer>)
 => (end-pos :: false-or(<integer>))
  let non-hyphen = find(markup, method (c) c ~== '-' end, start: start) | markup.size;
  if (non-hyphen - start >= 4)
    write(out, "<hr/>\n");
    non-hyphen
  end
end method parse-horizontal-line;

define method parse-less-than
    (out :: <stream>, markup :: <string>, start :: <integer>)
 => (end-pos :: false-or(<integer>))
  // don't search past newline...
  let close = find(markup, method (c) c == '>' | c == '\n' end, start: start);
  if (close & markup[close] == '>')
    let word = copy-sequence(markup, start: start + 1, end: close);
    select (word by case-insensitive-equal?)
      "br", "br/"
        => write(out, "<br/>");
           close + 1;
      "p", "p/"
        => write(out, "<p/>");
           close + 1;
      // add more paired elements here...
      "center", "center/"
        => write(out, markup, start: start, end: close + 1);
           close + 1;
      "nowiki"
        // TODO: allow nested nowiki elements.
        => let epos = index-of(markup, "</nowiki>",
                               test: case-insensitive-equal?,
                               start: close) | markup.size;
           write(out, markup, start: start + "<nowiki>".size, end: epos);
           epos + "</nowiki>".size;
      otherwise
        => write(out, "&lt;");
           start + 1;
    end select
  else
    write(out, "&lt;");
    start + 1
  end
end method parse-less-than;

define method parse-ampersand
    (out :: <stream>, markup :: <string>, start :: <integer>)
 => (end-pos :: false-or(<integer>))
  write(out, "&amp;");
  start + 1
end method parse-ampersand;

/* TODO...
define wiki-markup raw-url
    regex: "(http|ftp|gopher|mailto|news|nntp|telnet|wais|file|prospero)://[^ \t\r\n)]+";
    (stream, all, #rest ignore)
  format(stream, "<a href=\"%s\">%s</a>", all, all);
end;

*/

