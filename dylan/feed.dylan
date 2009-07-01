Module: wiki-internal

define method atom-feed-responder
    (#key type, name)
  let name = name & percent-decode(name);
  let (changes, description)
    = select (type by \=)
        "users" =>
          values(wiki-changes(change-type: <wiki-user-change>, name: name),
                 iff(name, concatenate("user ", name), "all users"));
        "groups" =>
          values(wiki-changes(change-type: <wiki-group-change>, name: name),
                 iff(name, concatenate("group ", name), "all groups"));
        "pages" =>
          values(wiki-changes(change-type: <wiki-page-change>, name: name),
                 iff(name, concatenate("page ", name), "all pages"));
        "tags" =>
          values(wiki-changes(change-type: <wiki-page-change>, tag: name),
                 iff(name, concatenate("pages tagged ", name), "all pages"));
        otherwise =>
          values(wiki-changes(), "");
      end;
  if (~empty?(description))
    description := concatenate(" to ", description);
  end;
  let changes = sort(changes,
                     test: method (change1, change2)
                             change1.date-published > change2.date-published
                           end);
  let date-updated = iff(empty?(changes),
                         current-date(),
                         changes.first.date-published);
  let feed-authors = #[];
  for (change in changes)
    for (author in change.authors)
      feed-authors := add-new!(feed-authors, author, test: \=);
    end for;
  end for;
  let feed = make(<feed>,
                  generator: make(<generator>,
                                  text: *site-name*,
                                  version: $wiki-version,
                                  uri: *site-url*),
                  title: *site-name*,
                  subtitle: concatenate("Recent changes", description),
                  updated: date-updated,
                  author: feed-authors,
                  categories: #[]);
  let url = build-uri(current-request().request-url);
  feed.identifier := url;
  feed.links["self"] := make(<link>, rel: "self", href: url);

  add-header(current-response(), "Content-Type", "application/atom+xml");
  output("%s", generate-atom(feed, entries: changes));
end method atom-feed-responder;

define method generate-atom (change :: <wiki-change>, #key)
  // todo -- enforce at least one author when any <entry> is created.
  let authors = change.authors;
  let author = ~empty?(authors) & find-user(first(authors));
  with-xml()
    entry { 
      title(change.title),
//      do(do(method(x) collect(generate-atom(x)) end, entry.links)),
      id(build-uri(change-identifier(change))),
      published(generate-atom(change.date-published)),
      updated(generate-atom(change.date-published)),
      do(if (author) generate-atom(author) end if),
//      do(do(method(x) collect(generate-atom(x)) end, entry.contributors)),
      do(collect(generate-atom(change.comments[0].content)))
    } //missing: category, summary
  end;
end;

define method generate-atom (user :: <wiki-user>, #key)
  with-xml()
    author {
      name(user.user-name),
      uri(build-uri(permanent-link(user)))
    }
  end;
end;


define method change-identifier (change :: <wiki-page-change>)
  let location = page-permanent-link(change.title);
  push-last(location.uri-path, "versions");
  push-last(location.uri-path, integer-to-string(change.change-version));
  location;
end;

define method change-identifier (change :: <wiki-group-change>)
  group-permanent-link(change.title)
end;

define method change-identifier (change :: <wiki-user-change>)
  user-permanent-link(change.title)
end;

