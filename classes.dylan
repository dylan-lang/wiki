module: wiki


define web-class <wiki-page-diff> (<object>)
  data content :: <string>;
  data author :: <string> = if (current-user()) current-user().username else "foobar" end; //XXX: use IP here
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
  element(*pages*, title, default: #f);
end;

define method find-backlinks (title)
  let res = make(<stretchy-vector>);
  for (page in sort(key-sequence(*pages*)))
    if (subsequence-position(latest-text(*pages*[page]), concatenate("[[", title, "]]")))
      add!(res, *pages*[page])
    end;
  end;
  res;
end;

define method remove-page (title)
  remove-key!(*pages*, title);
end;

define method rename-page (old-title, new-title)
  let page = find-page(old-title);
  *pages*[new-title] := page;
  //XXX write a changelog entry
  remove-page(old-title);
end;

//undo last change
define method undo (title)
  let page = find-page(title);
  if (page)
    let previous-version = page.revisions[page.revisions.size - 2];
    save-page(title, previous-version, comment: "revert to previous version");
  end;
end;

define method save-page (title, content, #key comment = "")
  let page = find-page(title);
  unless (page)
    page := make(<wiki-page-content>, page-title: title);
    *pages*[title] := page;
  end;
  let version = size(page.revisions) + 1;
  unless (version > 1 & content = page.latest-text)
    let revision = make(<wiki-page-diff>,
                        content: content,
                        page-version: version,
                        wiki-page-content: page,
                        comment: comment);
    add!(page.revisions, revision);
    save(revision);
  end;
end;

define responder worker-responder ("/worker")
 (request, response)
  if (user-logged-in?(request) & current-user().access <= 23)
    let action = as(<symbol>, get-query-value("action"));
    select (action)
      #"undo" => undo(get-query-value("title"));
      #"rename" => rename-page(get-query-value("oldtitle"), get-query-value("title"));
      #"remove" => remove-page(get-query-value("title"))
    end;
  end;
end;

