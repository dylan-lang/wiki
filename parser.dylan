Module: wiki
Synopsis: An ad-hoc parser for wiki markup
Author: Carl Gay
Copyright: This code is in the public domain.


// TODO: Make wiki markup tags case insensitive.

define variable *wiki-link-url* = "/wiki/view.dsp?title=";

define class <matcher> (<object>)
  constant slot matcher-name :: <string>, required-init-keyword: #"name";
  constant slot matcher-regex :: <string>, required-init-keyword: #"regex";
  // function is passed a stream and strings corresponding
  // to the groups specified in the regex (the first string
  // is the entire match).  The function must generate HTML
  // on the given stream.
  constant slot matcher-function :: <function>, required-init-keyword: #"function";
end;

define constant $matchers :: <stretchy-vector> = make(<stretchy-vector>);

define function add-matcher
    (name, regex, fun)
  let new = make(<matcher>, name: name, regex: regex, function: fun);
  let idx = position($matchers, new,
                     test: method (x, y)
                             string-equal?(x.matcher-name, y.matcher-name)
                           end);
  if (idx)
    $matchers[idx] := new;
  else
    add!($matchers, new);
  end
end;

define macro wiki-markup-definer
    { define wiki-markup ?:name regex: ?regex:expression; (?arglist:*) ?:body end }
 => { begin
        define method "parse-" ## ?name (?arglist) ?body end;
        add-matcher(?"name", ?regex, "parse-" ## ?name);
      end;
    }
end;


define method wiki-markup-to-html
    (text :: <string>, #key start = 0)
 => (html :: <string>)
  with-output-to-string (html-stream)
    let bpos :: <integer> = start;
    while (bpos < text.size)
      let min-pos :: <integer> = text.size;
      let matcher = #f;
      let positions = #[];
      let longest-match = 0;

      //log-debug("Starting match at %=",
      //          copy-sequence(text, start: bpos, end: min(text.size, bpos + 10)));
      // find nearest match
      for (m in $matchers)
        // regexp-position returns two values for each group.  The first
        // pair is for the start/end of the entire match.
        let (#rest indexes) = regexp-position(text, m.matcher-regex, start: bpos);
        if (indexes.size > 1)
          let match-start :: <integer> = indexes[0];
          let match-end :: <integer> = indexes[1];
          let match-size :: <integer> = match-end - match-start;
          if (~matcher
              | match-start < min-pos
              | (match-start == min-pos & match-size > longest-match))
            positions := indexes;
            min-pos := match-start;
            matcher := m;
            longest-match := match-size;
            //log-debug("Matched %= with %=", m.matcher-name,
            //          copy-sequence(text, start: match-start, end: match-end));
          end;
        end;
      end for;

      if (min-pos > bpos)
        //log-debug("Inter-markup: %=", copy-sequence(text, start: bpos, end: min-pos));
        write(html-stream, copy-sequence(text, start: bpos, end: min-pos))
      end;
      if (matcher)
        let strings = make(<vector>, size: floor/(positions.size, 2));
        for (i from 0 below strings.size)
          strings[i] := copy-sequence(text, start: positions[i * 2], end: positions[i * 2 + 1]);
          //log-debug("Match string: %=", strings[i]);
        end;
        let length-used = apply(matcher.matcher-function, html-stream, strings);
        bpos := if (length-used)
                  min-pos + length-used
                else
                  positions[1];  // end of entire match
                end;
      else
        bpos := text.size;  // exit while loop
      end;
    end while;
  end with-output-to-string
end method wiki-markup-to-html;


// Markup: == heading ==
// HTML:   <h2>heading</h2>
//
define wiki-markup heading
    // There must be two or more '=' on both sides of the header.
    regex: "(^|\\s+)(==+)([^=\n]+)==+(\\s*\n|$)";
    (stream, all, white, tag, header, white)
  // TODO: what's the max n for <hn> elements?
  format(stream, "<h%d>%s</h%d>\n", tag.size, header, tag.size);
  all.size - white.size
end;

// Markup: [[...]]
// HTML:   <A HREF="...">...</A>
//
define wiki-markup internal-link
    regex: "\\[\\[\\s*([^\\]]*)\\s*]]";
    (stream, entire-match, wiki-title)
  format(stream, "<a href=\"%s%s\">%s%s</a>",
         *wiki-link-url*,
         wiki-title,
         if (page-exists?(wiki-title)) "" else "[?]" end,
         wiki-title);
end;

// [url|link text]
define wiki-markup external-link
    regex: "\\[\\s*([^\\]|]*)(\\|([^\\]]*))?]";
    (stream, all, url, bar-group, label)
  format(stream, "<a href=\"%s\">%s</a>", url, label | url);
end;

// Blank lines generate <P> tags.
define wiki-markup paragraph
    regex: "\r\n\\s*\r\n|\n\\s*\n";
    (stream, entire-match)
  write(stream, "<p></p>\n");
end;

// Lines that start with spaces or tabs are preformatted.
//
define wiki-markup preformat
    regex: "(\r?\n([ \t]+\\S[^\r\n]*))+";
    (stream, entire-match, #rest ignore)
  format(stream, "<pre>%s</pre>\n", entire-match);
end;

define wiki-markup bullet-list
    // Match the entire bulletted list, not just one bullet.
    regex: "((^|\r?\n)\\s*[*][^\r\n]*)+";
    (stream, entire-match, #rest ignore)
  generate-list(stream, entire-match, '*', "ul");
end;

define wiki-markup numbered-list
    // Match the entire bulletted list, not just one bullet.
    regex: "((^|\r?\n)\\s*#[^\r\n]*)+";
    (stream, entire-match, #rest ignore)
  generate-list(stream, entire-match, '#', "ol");
end;

define method generate-list
    (stream, wiki-markup, bullet-char, tag)
  write(stream, "<p>\n");
  let lines = split(wiki-markup, separator: "\n", trim?: #t);
  let depth :: <integer> = 0;
  let regex = format-to-string("^\\s*([%s]+)", bullet-char);
  for (line in lines)
    let (#rest indexes) = regexp-position(line, regex);
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
end method generate-list;

define wiki-markup horizontal-line
    regex: "(^|\r?\n)----+(\\s*)";
    (stream, all, start, stop)
  write(stream, "<hr/>\n");
  all.size - stop.size
end;

define wiki-markup nowiki
    regex: "<nowiki>((.|\n)*)</nowiki>";
    (stream, entire-match, #rest ignore)
  // The regexp matcher is greedy, so we have to find the nearest
  // </nowiki> by hand.
  // TODO: implement nested <nowiki>s.
  let close = subsequence-position(entire-match, "</nowiki>");
  write(stream, copy-sequence(entire-match,
                              start: size("<nowiki>"),
                              end: close | (entire-match.size - "</nowiki>".size)));
end;

define wiki-markup raw-url
    regex: "(http|ftp|gopher|mailto|news|nntp|telnet|wais|file|prospero)://[^ \t\r\n)]+";
    (stream, all, #rest ignore)
  format(stream, "<a href=\"%s\">%s</a>", all, all);
end;

define wiki-markup acceptable-html-elements
    regex: "<(br|center|p)[ \t]+/?>";	// others?
    (stream, all, name)
  format(stream, "<%s/>", name);
end;

define wiki-markup escape-less-than
    regex: "<";
    (stream, entire-match, #rest ignore)
  write(stream, "&lt;");
end;

define wiki-markup escape-ampersand
    regex: "&";
    (stream, entire-match, #rest ignore)
  write(stream, "&amp;");
end;

