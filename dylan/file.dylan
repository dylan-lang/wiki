module: wiki-internal

define thread variable *file-filename* = #f;


// class

define class <wiki-file> (<object>) 
  slot file-filename :: <string>,
    required-init-keyword: filename:;
end;

define object-test (file) in wiki end;

/*
define action-tests
 (add-file, edit-file, remove-file, list-file)
in wiki end;
*/

define error-test (filename) in wiki end;


// verbs

*change-verbs*[<wiki-file-change>] :=
  table(#"edit" => "edited",
	#"removal" => "removed",
	#"renaming" => "renamed",
	#"add" => "uploaded");


// url

define method permanent-link
    (file :: <wiki-file>, #key escaped?, full?)
 => (url :: <url>);
  file-permanent-link(file.file-filename);
end;

define method file-permanent-link
    (filename :: <string>)
 => (url :: <url>);
  let location = parse-url("/files/");
  last(location.uri-path) := filename;
  transform-uris(*wiki-url*, location, as: <url>);
end;

define method redirect-to (file :: <wiki-file>)
  redirect-to(permanent-link(file));
end;


// methods

define method find-file
    (filename :: <string>)
 => (file :: false-or(<wiki-file>));
  element(storage(<wiki-file>), filename, default: #f);
end;


define method save-file
    (filename :: <string>, contents :: false-or(<byte-string>),
     #key comment :: <string> = "")
 => ();
  let file :: false-or(<wiki-file>) = find-file(filename);
  let action :: <symbol> = #"edit";
  if (file)
    if (contents)
      //TODO: write new contents
    end if;
  else
    file := make(<wiki-file>, filename: filename);
    //TODO: write contents
    action := #"add";
  end;
  save-change(<wiki-file-change>, filename, action, comment);
  save(file);
  dump-data();
end;

define method rename-file
    (filename :: <string>, new-filename :: <string>,
     #key comment :: <string> = "")
 => ();
  let file = find-file(filename);
  if (file)
    rename-file(file, new-filename, comment: comment)
  end if;
end;

define method rename-file
    (file :: <wiki-file>, new-filename :: <string>,
     #key comment :: <string> = "")
 => ();
  let comment = concatenate("was: ", file.file-filename, ". ", comment);
  remove-key!(storage(<wiki-file>), file.file-filename);
  file.file-filename := new-filename;
  storage(<wiki-file>)[new-filename] := file;
  //TODO: rename file
  save-change(<wiki-file-change>, new-filename, #"renaming", comment);
  save(file);
  dump-data();
end;

define method remove-file
    (file :: <wiki-file>,
     #key comment :: <string> = "")
 => ();
  save-change(<wiki-file-change>, file.filename, #"removal", comment);
  remove-key!(storage(<wiki-file>), file.filename);
  //TODO: remove file
  dump-data();
end;


// pages

//define variable *view-file-page* =
//  make(<wiki-dsp>, source: "view-file.dsp");

define variable *edit-file-page* = 
  make(<wiki-dsp>, source: "edit-file.dsp");

define variable *list-files-page* =
  make(<wiki-dsp>, source: "list-files.dsp");

define variable *remove-file-page* =
  make(<wiki-dsp>, source: "remove-file.dsp");

define variable *non-existing-file-page* =
  make(<wiki-dsp>, source: "non-existing-file.dsp");


// actions

define method do-files ()
  case
    get-query-value("go") =>
      redirect-to(file-permanent-link(get-query-value("query")));
    otherwise =>
      process-page(*list-files-page*);
  end;
end;

define method bind-file (#key filename)
  *file* := find-file(percent-decode(filename));
end;

define method show-file (#key filename)
  dynamic-bind (*file-filename* = percent-decode(filename))
    respond-to(#"get", case
	                 //TODO: *file* => *view-file-page*;
			 otherwise => *edit-file-page*;
                       end case);
  end;
end method show-file;

define method show-edit-file (#key filename)
  dynamic-bind (*file-filename* = percent-decode(filename))
    respond-to(#"get", case
	                 *file* => *edit-file-page*;
			 otherwise => *non-existing-file-page*;
                       end case);
  end;
end method show-edit-file;

define method do-save-file (#key filename)
  let filename = percent-decode(filename);
  let new-filename = get-query-value("filename");
  let uploaded-file = get-query-value("file");
  let comment = get-query-value("comment");
  let file = find-file(filename);  
  let errors = #();
 
  format-out("%=, %=, %=, %=\n", filename, new-filename, uploaded-file, file);
/*  
  if (~ instance?(username, <string>) | username = "" |
      (new-username & (~ instance?(new-username, <string>) | new-username = "")))
    errors := add!(errors, #"username");
  end if;

  if (file)
     if (uploaded-file = "")
       password := #f;
     end if; 
  else
    if (~ instance?(password, <string>) | password = "")
      errors := add!(errors, #"password");
    end if;
  end if;
*/

/*
  if (user & new-username & new-username ~= username & new-username ~= "")
    if (find-user(new-username))
      errors := add!(errors, #"exists");
    else
      rename-user(user, new-username, comment: comment);
      username := new-username;
    end if;
  end if;

  if (empty?(errors))
    save-user(username, password, email);
    redirect-to(find-user(username));
  else
    current-request().request-query-values["password"] := "";
    dynamic-bind (*errors* = errors, *form* = current-request().request-query-values)
      respond-to(#"get", *edit-user-page*);
    end;
  end if;
*/
  
end method do-save-file;

define method do-remove-file (#key filename)
  let file = find-file(percent-decode(filename));
  remove-file(file, comment: get-query-value("comment"));
  redirect-to(file);
end;

define method redirect-to-file-or (page :: <page>, #key filename)
  if (*file*)
    respond-to(#"get", page);
  else
    redirect-to(file-permanent-link(percent-decode(filename)));
  end if;
end;

define constant show-remove-file =
  curry(redirect-to-file-or, *remove-file-page*);


// tags

define tag show-file-filename in wiki (page :: <wiki-dsp>)
 ()
  output("%s", if (*file*)
      escape-xml(*file*.file-filename)
    elseif (*form* & element(*form*, "filename", default: #f))
      escape-xml(*form*["filename"])
    elseif (*file-filename*)
      *file-filename*
    else "" end if);
end;

define tag show-file-permanent-link in wiki (page :: <wiki-dsp>)
 (use-change :: <boolean>)
  output("%s", if (use-change)
      file-permanent-link(*change*.title);
    elseif (*file*)
      permanent-link(*file*)
    else "" end if);
end;


// body tags

define body tag list-files in wiki
 (page :: <wiki-dsp>, do-body :: <function>)
 ()
  for (file in storage(<wiki-file>))
    dynamic-bind(*file* = file)
      do-body();
    end;
  end for;
end;


// named methods

define named-method file-changed? in wiki (page :: <wiki-dsp>)  
  instance?(*change*, <wiki-file-change>);
end;
