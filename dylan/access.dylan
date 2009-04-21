Module: wiki-internal

//// Access Control Lists

/*

How ACLs work...

There are three types of access defined:

* read-content
* modify-content
* modify-acls

In the future it may be useful to define additional types of access.

Permissions may be granted to specific users, groups of users, and
three pre-defined groups:

* anyone -- anyone at all
* trusted -- anyone who can login
* owner -- owner of the page

Any access rule may be negated, so that for example "deny anyone"
or "deny <user>" may be specified.  In the code this is represented
as a sequence such as #(deny:, <user>).

If no ACLs are set for a page then the default ACLs are used instead.
(The defaults need to be made configurable.)

Once you set any ACLs at all for a page, they fully determine the
access rights.  For example, there is no global default for everyone
to be able to read a page unless explicitly disabled.  This means,
for example, that if you want to prevent a specific group from
viewing a page you must specify a read-content ACL like this:

  deny <group>
  allow anyone

If "anyone" isn't included then no read access is granted to anyone
(including the group).

ACLs are tested in order; the first access rule to match either
grants or denies the permission.  For example, if an admin or the
page owner wants to quickly disable a page they could simply add
"deny anyone" at the front of the ACLs.

Note that admins are always allowed all access.

Example: Anyone but cgay and group1 can view content

  view-content: list(list(deny:, <user cgay>),
                     list(deny:, <group group1>),
                     list(allow:, $anyone))

*/

define constant $view-content = #"view-content";
define constant $modify-content = #"modify-content";
define constant $modify-acls = #"modify-acls";
define constant <acl-operation> :: <type>
  = one-of($view-content, $modify-content, $modify-acls);

define constant $anyone = #"anyone";
define constant $trusted = #"trusted";
define constant $owner = #"owner";

define constant <acl-target> //:: <type>
  = type-union(<symbol>, //one-of($anyone, $trusted, $owner),
               <wiki-user>,
               <wiki-group>);

define class <acls> (<object>)
  constant slot view-content-rules :: <sequence> = #(),
    init-keyword: view-content:;
  constant slot modify-content-rules :: <sequence> = #(),
    init-keyword: modify-content:;
  constant slot modify-acls-rules :: <sequence> = #(),
    init-keyword: modify-acls:;
end class <acls>;

define method make
    (class :: subclass(<acls>), #key view-content, modify-content, modify-acls)
 => (object :: <acls>)
  // Make sure the ACLs can't be modified by mutating the sequences
  // after creation.  Is there a better way to write this?
  apply(next-method, class,
        view-content: copy-sequence(view-content | #()),
        modify-content: copy-sequence(modify-content | #()),
        modify-acls: copy-sequence(modify-acls | #()),
        #())
end method make;

define method initialize
    (acls :: <acls>, #key)
  do(validate-acl-rule, acls.view-content-rules);
  do(validate-acl-rule, acls.modify-content-rules);
  do(validate-acl-rule, acls.modify-acls-rules);
end method initialize;

define function validate-acl-rule (rule)
  assert(instance?(rule, <sequence>),
         "Invalid ACL rule, %s, must be a sequence.", rule);
  assert(rule.size = 2,
         "Invalid ACL, %s, must be a two element sequence.", rule);
  let (action, target) = apply(values, rule);
  assert(member?(action, #(allow:, deny:)),
         "Invalid ACL action: %s must be allow: or deny:.", action);
  assert(instance?(target, <acl-target>), "Invalid ACL target: %s", target);
end function validate-acl-rule;

// Default access controls applied to pages that don't otherwise specify
// any ACLs.  (But admins are omnipotent.)
//
define constant $default-access-controls
  = make(<acls>,
         view-content: list(list(allow:, $anyone)),
         modify-content: list(list(allow:, $trusted)),
         modify-acls: list(list(allow:, $owner)));

define method has-permission?
    (user :: false-or(<user>),
     page :: <wiki-page>,
     requested-operation :: <acl-operation>)
 => (has-permission? :: <boolean>)
  // If user is #f then they're not logged in.

  // Admins can do anything for now.  Eventually it may be useful to have
  // two levels of admins: those who can modify any content and those who
  // can do anything.

  // Page owner cannot be denied access either.  (If an admin wants to do
  // that they should be able to handle it via other means, such as disabling
  // the account or changing the page owner.)  I'm actually not totally sure
  // this is the right design decision.  My thinking is that it's too easy
  // for the owner to accidentally lock him/herself out, and it could generate
  // a lot of admin requests.

  if (user & (administrator?(user) | page.page-owner = user))
    #t
  else
    let acls :: <acls> = page.access-controls;
    let rules :: <sequence> = select (requested-operation)
                                $view-content => acls.view-content-rules;
                                $modify-content => acls.modify-content-rules;
                                $modify-acls => acls.modify-acls-rules;
                              end;
    block (return)
      for (rule in rules)
        let (action, target) = apply(values, rule);
        // First match wins
        if (target = $anyone
              | (user
                   & (target = user
                        | (target = $trusted & user = authenticated-user())
                        | (target = $owner & page.page-owner = user)
                        | (instance?(target, <wiki-group>)
                             & member?(user, target.group-members)))))
          return(action = allow:)
        end if;
      end for;
      #f          // default is no permission if no rule matches
    end block
  end if
end method has-permission?;

// Turn a user-entered string into the internal representation of rules.
// The string is one rule per line.  '!' means deny.  Lack of '!' means
// allow.  e.g., "!cgay\n!foo\ntrusted".  Blank lines and '!' on a line
// by itself are removed.  If there's an error parsing a rule, such as
// user not found, then instead of the parsed rule a list of
// #(original-rule, error-message) is returned.  For example:
//   "!no-such-user"
// =>
//   #(#("!no-such-user", "User no-such-user not found."))
// The caller can use this for error reporting purposes.
//
define method parse-rules
    (rules :: <string>) => (rules :: <sequence>, error? :: <boolean>)
  let error? = #f;
  local method parse-one-rule (rule)
    let (parsed-rule, err?) = parse-rule(rule);
    if (parsed-rule)
      error? := error? | err?;
      parsed-rule
    end
  end;
  values(choose(identity, map(parse-one-rule, split(rules, '\n'))),
         error?)
end method parse-rules;

// Return two values: a parsed rule rule like #(deny:, <user cgay>) and
// whether or not there were any errors.  If there is an error, such as
// group not found, include #(original-rule, error-message) for the erring
// rule.
//
define method parse-rule
    (rule :: <string>)
 => (rule :: false-or(<sequence>), errors? :: <boolean>)
  let rule = trim(rule);
  let action = allow:;
  if (rule.size > 0)
    if (rule[0] = '!')
      action := deny:;
      rule := copy-sequence(rule, start: 1);
    end;
    if (rule.size > 0)
      select (as-lowercase(rule) by \=)
        "trusted" => list(action, $trusted);
        "anyone" => list(action, $anyone);
        "owner" => list(action, $owner);
        otherwise =>
          let target = find-user(rule) | find-group(rule);
          if (target)
            list(action, target)
          else
            let msg = format-to-string("No user or group named %s was found.",
                                       rule);
            values(list(rule, msg), #t)
          end;
      end
    end
  end
end method parse-rule;
      
// Turn the internal representation of rules into something users
// can read and edit.
//
define method unparse-rules
    (rules :: <sequence>) => (rules :: <string>)
  join(map(unparse-rule, rules), "\n")
end;

define method unparse-rule
    (rule :: <sequence>) => (rule :: <string>)
  let (action, target) = apply(values, rule);
  concatenate(select (action)
                allow: => "";
                deny:  => "!";
              end,
              select (target by instance?)
                <symbol> => as-lowercase(as(<string>, target));
                <user> => target.username;
                <wiki-group> => target.group-name;
                otherwise => error("Invalid rule target: %s", target);
              end)
end method unparse-rule;

define class <acls-page> (<wiki-dsp>)
end;

define constant $edit-access-page
  = make(<acls-page>, source: "edit-page-access.dsp");

define method respond-to-get
    (acls-page :: <acls-page>, #key title :: <string>)
  let wiki-page = find-page(percent-decode(title));
  if (wiki-page)
    set-attribute(page-context(), #"owner-name", wiki-page.page-owner.username);
    dynamic-bind (*page* = wiki-page)
      next-method()
    end;
  else
    redirect-to($non-existing-page-page);
  end;
end method respond-to-get;

// Handle the page access form submission.
// todo -- Redisplay the user-entered text when there's an error, but with
//         a * next to the broken entries?  <wiki:show-rules> needs to display
//         this text instead of the actual page rules.
//         Display an error message too.
//
define method respond-to-post
    (acls-page :: <acls-page>, #key title :: <string>)
  let wiki-page = find-page(percent-decode(title));
  with-query-values (view-content, modify-content, modify-acls, comment)
    let (vc-rules, vc-err?) = parse-rules(view-content);
    let (mc-rules, mc-err?) = parse-rules(modify-content);
    let (ma-rules, ma-err?) = parse-rules(modify-acls);
    if (vc-err? | mc-err? | ma-err?)
      local method note-errors (rules, field-name)
              for (rule in rules)
                let (action, target) = apply(values, rule);
                if (~member?(action, #(allow:, deny:)))
                  note-form-error(target, field-name: field-name)
                end;
              end;
            end;
      note-errors(vc-rules, "view-content");
      note-errors(mc-rules, "modify-content");
      note-errors(ma-rules, "modify-acls");
      dynamic-bind (wf/*form* = current-request().request-query-values)
        respond-to-get(acls-page, title: title);
      end;
    else
      wiki-page.access-controls := make(<acls>,
                                        view-content: vc-rules,
                                        modify-content: mc-rules,
                                        modify-acls: ma-rules);
      redirect-to(wiki-page);
    end;
  end;
end method respond-to-post;

define tag show-rules in wiki
    (acls-page :: <acls-page>)
    (name :: <string>)
  let name = as-lowercase(name);
  let acls = *page*.access-controls;
  output("%s", unparse-rules(select (name by \=)
                               "view-content" => acls.view-content-rules;
                               "modify-content" => acls.modify-content-rules;
                               "modify-acls" => acls.modify-acls-rules;
                               otherwise =>
                                 error("Invalid rule type: %s", name);
                             end));
end;

define named-method can-view-content? in wiki
    (acls-page :: <acls-page>)
  has-permission?(authenticated-user(), *page*, $view-content)
end;

define named-method can-modify-content? in wiki
    (acls-page :: <acls-page>)
  has-permission?(authenticated-user(), *page*, $modify-content)
end;

define named-method can-modify-acls? in wiki
    (acls-page :: <acls-page>)
  has-permission?(authenticated-user(), *page*, $modify-acls)
end;

