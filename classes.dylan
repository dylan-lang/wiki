module: wiki


define web-class <wiki-page-diff> (<object>)
  data content :: <string>;
  data author :: <string> = if (current-user())
                              current-user().username
                            else
                              "foobar"  //XXX: use IP here
                            end;
  data page-version :: <integer>;
  data timestamp :: <date> = current-date();
  data comment :: <string>;
  has-a wiki-page-content;
end;

define web-class <wiki-page-content> (<reference-object>)
  data page-title :: <string>;
  has-many revision :: <wiki-page-diff>;
end;

define inline-only method key (page :: <wiki-page-content>) => (res :: <string>);
  page.page-title;
end;

define method latest-text (page :: <wiki-page-content>) => (text :: <string>)
  page.revisions.last.content
end;

define method find-page (title)
  element(storage(<wiki-page-content>), title, default: #f);
end;

define method find-backlinks (title)
  let res = make(<stretchy-vector>);
  for (page in sort(key-sequence(storage(<wiki-page-content>))))
    if (subsequence-position(latest-text(storage(<wiki-page-content>)[page]),
                             concatenate("[[", title, "]]")))
      add!(res, storage(<wiki-page-content>)[page])
    end;
  end;
  res;
end;

define function xmpp-worker ()
  if (option-value-by-long-name(*argument-list-parser*, "xmpp"))
    block()
      *xmpp-bot* := make(<xmpp-bot>,
                         jid: "dylanbot@jabber.berlin.ccc.de/serva",
                         password: "fnord");
      sleep(3); //this is for safety reasons, xml-parser is not thread-safe!
    exception (e :: <condition>)
      *xmpp-bot* := #f
    end block;
  end if;
end;

define method save (diff :: <wiki-page-diff>) => ()
  next-method();
  block()
    let com = if (diff.comment = "")
                "empty"
              else
                diff.comment
              end;
    let text = concatenate(diff.wiki-page-content.page-title,
                           " (\"http://wiki.opendylan.org/wiki/view.dsp?title=",
                           diff.wiki-page-content.page-title, "\")",
                           " [version ", integer-to-string(diff.page-version),
                           "] was changed by ", diff.author,
                           " comment was ", com);
    broadcast-message(*xmpp-bot*, text);
  exception (e :: <condition>)
    xmpp-worker();
  end;
end;

define method save-page (title, content, #key comment = "")
  let page = find-page(title);
  unless (page)
    page := make(<wiki-page-content>, page-title: title);
    save(page);
  end;
  let version = size(page.revisions) + 1;
  unless (version > 1 & content = page.latest-text)
    let revision = make(<wiki-page-diff>,
                        content: content,
                        page-version: version,
                        wiki-page-content: page,
                        comment: comment);
    with-storage (pages = <wiki-page-content>)
      add!(page.revisions, revision);
    end;
    save(revision);
    //need to store dependency (page, because page.revisions was updated)
    save(page);
    dump-data();
  end;
end;

begin
  add-option-parser-by-type(*argument-list-parser*,
                            <simple-option-parser>,
                            description: "Whether to enable the XMPP bot",
                            long-options: #("xmpp"));
  register-url("/wiki/wiki.css", maybe-serve-static-file);
  register-init-function(xmpp-worker);
  koala-main();
end;
