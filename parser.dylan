Module: wiki
Synopsis: An ad-hoc parser for wiki markup
Author: Carl Gay
Copyright: This code is in the public domain.


define variable *wiki-link-url* = "/wiki/view.dsp?title=";

// Each element of $matchers is a vector of two elements.  The first element
// is a regular expression (string) and the second is a function to call if
// that regular expression matches some wiki markup.  The function will be
// passed a sequence of strings corresponding to the groups specified
// in the regex.  The first string is the entire match.
//
define constant $matchers :: <stretchy-vector> = make(<stretchy-vector>);

/*
define wiki-markup bold
    regex: "''(.*)''";
    (stream, entire-match, group1)
  write(stream, fmt("<B>%s</B>", group1))
end;
*/
// TODO: This doesn't work well with incremental compilation of callers.
//       Need to make it replace the old matcher rather than just adding
//       a new one, which means holding onto the name.
define macro wiki-markup-definer
    { define wiki-markup ?:name regex: ?regex:expression; (?arglist:*) ?:body end }
 => { begin
        define method "parse-" ## ?name (?arglist) ?body end;
        add!($matchers, vector(?regex, "parse-" ## ?name));
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
      let parser = #f;
      let positions = #f;

      // find nearest match
      for (matcher in $matchers)
        let (regex, fun) = apply(values, matcher);
        // regexp-position returns two values for each group.  The first
        // pair is for the start/end of the entire match.
        let (#rest indexes) = regexp-position(text, regex, start: bpos);
        if (indexes.size > 1)
          let match-start :: <integer> = indexes[0];
          if (~positions | match-start < min-pos)
            positions := indexes;
            min-pos := match-start;
            parser := fun;
          end;
        end;
      end for;

      if (min-pos > bpos)
        write(html-stream, copy-sequence(text, start: bpos, end: min-pos))
      end;
      if (positions)
        let strings = make(<vector>, size: floor/(positions.size, 2));
        for (i from 0 below strings.size)
          strings[i] := copy-sequence(text, start: positions[i * 2], end: positions[i * 2 + 1])
        end;
        let length-used = apply(parser, html-stream, strings);
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
// HTML:   <H2>heading</H2>
//
define wiki-markup heading
    // There must be two or more '=' on both sides of the header.
    regex: "(^|\n)\\s*(==+)([^=\n]+)==+\\s*(\n|$)";
    (stream, entire-match, ignore, tag, header, ignore)
  format(stream, "<H%d>%s</H%d>\n", tag.size, header, tag.size);
end;

// Markup: [[...]]
// HTML:   <A HREF="...">...</A>
//
define wiki-markup link
    regex: "\\[\\[\\s*(.*)\\s*]]";
    (stream, entire-match, wiki-title)
  format(stream, "<A HREF=\"%s%s\">%s%s</A>",
         *wiki-link-url*,
         wiki-title,
         if (page-exists?(wiki-title)) "" else "[?]" end,
         wiki-title);
end;

// Blank links generate <P> tags.
define wiki-markup paragraph
    regex: "\n\\s*(\n|$)";
    (stream, entire-match, ignore)
  format(stream, "<P></P>\n");
end;

// Lines that start with spaces or tabs are preformatted.
//
define wiki-markup preformat
    regex: "(\n([ \t]+\\S.*))+";
    (stream, entire-match, #rest ignore)
  format(stream, "<PRE>%s</PRE>\n", entire-match);
end;

define wiki-markup bullet-list
    // Match the entire bulletted list, not just one bullet.
    regex: "((^|\n)\\s*[*].*)+";
    (stream, entire-match, #rest ignore)
  generate-list(stream, entire-match, '*', "UL");
end;

define wiki-markup numbered-list
    // Match the entire bulletted list, not just one bullet.
    regex: "((^|\n)\\s*#.*)+";
    (stream, entire-match, #rest ignore)
  generate-list(stream, entire-match, '#', "OL");
end;

define method generate-list
    (stream, wiki-markup, bullet-char, tag)
  let lines = split(wiki-markup, separator: "\n", trim?: #t);
  let depth :: <integer> = 0;
  let regex = format-to-string("^\\s*([%s]+)", bullet-char);
  for (line in lines)
    let (#rest indexes) = regexp-position(line, regex);
    if (indexes)
      let bullet-start = indexes[2];
      let bullet-end = indexes[3];
      let num-bullets = bullet-end - bullet-start;
      let item-html = wiki-markup-to-html(line, start: bullet-end);
      case
        num-bullets < depth =>
          format(stream, "</%s>\n<LI>%s</LI>", tag, item-html);
          dec!(depth);
        num-bullets = depth =>
          format(stream, "<LI>%s</LI>\n", item-html);
        num-bullets > depth =>
          format(stream, "<%s>\n<LI>%s</LI>", tag, item-html);
          inc!(depth);
      end case;
    end if;
  end for;
  for (i from 0 to depth)
    format(stream, "</%s>\n", tag);
  end;
end method generate-list;

