Module:   %wiki
Synopsis: Parser for augmented RST markup
Author:   Carl Gay

// See README.txt for a description of the markup language we parse here.

define variable *python-executable* :: <string> = "python";
define variable *rst2html*          :: <string> = "rst2html.py";
define variable *rst2html-template* :: <string> = "rst2html-template.txt";

define variable *markup-prefix* :: <string> = "{{";
define variable *markup-suffix* :: <string> = "}}";


/// External entry point to the parser.
///
define method wiki-markup-to-html
    (markup :: <string>, title :: <string>,
     #key start :: <integer> = 0)
 => (html :: <string>)
  let chunks :: <sequence> = parse-wiki-markup(markup, title);
  rst2html(chunks)
end method wiki-markup-to-html;

define function parse-wiki-markup
    (markup :: <string>, title :: <string>)
 => (rst-chunks :: <sequence>)
  let chunks :: <sequence> = make(<stretchy-vector>);
  iterate loop (start :: <integer> = 0)
    if (start < markup.size)
      let markup-bpos = index-of(markup, *markup-prefix*, start: start);
      if (~markup-bpos)
        add!(chunks, slice(markup, start, #f));
      else
        add!(chunks, slice(markup, start, markup-bpos));
        let in-bpos = markup-bpos + *markup-prefix*.size;
        let markup-epos = index-of(markup, *markup-suffix*, start: in-bpos);
        if (markup-epos)
          // For now only handle {{Page Name}}
          let title = trim(slice(markup, in-bpos, markup-epos));
          add!(chunks, make-page-anchor(title, title));
          loop(markup-epos + *markup-suffix*.size);
        else
          error("Wiki markup close tag (%=) not found at index %d in page %s",
                *markup-suffix*, markup-bpos, title);
        end;
      end if;
    end if;
  end iterate;
  chunks
end function parse-wiki-markup;

define function rst2html
    (rst-chunks :: <sequence>) => (html :: <string>)
  let command = format-to-string("%s %s --template %s",
                                 *python-executable*, *rst2html*, *rst2html-template*);
  let error = #f;
  let html = "";
  let process = #f;
  block ()
    log-debug("running rst2html");
    let (exit-code, signal, child, stdin, stdout, stderr)
      = run-application(command,
                        asynchronous?: #t,
                        input: #"stream", output: #"stream", error: #"stream");
    log-debug("ran rst2html");
    process := child;
    for (chunk in rst-chunks)
      write(stdin, chunk);
    end;
    force-output(stdin);
    close(stdin);
    html := read-to-end(stdout);
    error := read-to-end(stderr);
    log-debug("read stderr %d bytes", error.size);
  cleanup
    // prevent zombies
    process & wait-for-application-process(process);
  end;
  if (~empty?(error))
    log-error("stderr: %s", error);
  end;
  html
end function rst2html;


/// Make an RST link to the page with the given title.
define function make-page-anchor
    (title :: <string>, text :: <string>) => (link :: <string>)
  format-to-string("`%s %s<%s/page/view/%s>`_",
                   text,
                   iff(page-exists?(title), "", "[?]"),
                   *wiki-url-prefix*,
                   percent-encode($uri-pchar, title))
end;

