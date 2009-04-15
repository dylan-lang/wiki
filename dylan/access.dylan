Module: wiki-internal

//// Access Control Lists

/*

How ACLs work...

There are three types of access defined:

* read-content
* modify-content
* modify-acl

In the future it may be useful to define additional types of access.

Permissions may be granted to specific users, groups of users, and
three pre-defined groups:

* anyone -- anyone at all
* trusted -- anyone who can login
* owner -- owner of the page

Any access specification may be negated, so that for example "deny
anyone" or "deny <user>" may be specified.  In the code this is
represented as a sequence such as #(deny:, <user>).

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

ACLs are tested in order; the first access specification to match
either grants or denies the permission.  For example, if an admin
or the page owner wants to quickly disable a page they could simply
add "deny anyone" at the front of the ACLs.

Note that admins are always allowed all access.

Example: Anyone but cgay and group1 can view content

  list($view-content, list(list(deny:, <user cgay>),
                           list(deny:, <group group1>),
                           list(allow:, $anyone)))

*/

define constant $view-content = #"view-content";
define constant $modify-content = #"modify-content";
define constant $modify-acl = #"modify-acl";
define constant <acl-operation> :: <type>
  = one-of($view-content, $modify-content, $modify-acl);

define constant $anyone = #"anyone";
define constant $trusted = #"trusted";
define constant $owner = #"owner";

/*
define class <acl> (<object>)
  slot allowed-to-view-content :: <sequence> = #();
  slot denied-to-view-content :: <sequence> = #();
  slot allowed-to-modify-content :: <sequence> #();
  slot denied-to-modify-content :: <sequence>;
  slot allowed-to-modify-acls;
  slot denied-to-modify-acls;
*/

// Default access controls applied to pages that don't otherwise specify
// any ACLs.  (But admins are omnipotent.)
//
define constant $default-access-control
  = list(list($view-content,   list(list(allow:, $anyone))),
         list($modify-content, list(list(allow:, $trusted))),
         list($modify-acl,     list(list(allow:, $owner))));

define method has-permission?
    (user :: false-or(<user>),
     page :: <wiki-page>,
     requested-operation :: <acl-operation>)
 => (has-permission? :: <boolean>)
  // If user is #f then they're not logged in.

  // Admins can do anything for now.  Eventually it may be useful to have
  // two levels of admins: those who can modify any content and those who
  // can do anything.
  let result = 
  if (user & administrator?(user))
    #t
  else
    let acls = page.access-controls;
    if (empty?(acls))
      acls := $default-access-control;
    end;
    block (return)
      for (acl in acls)
        let op :: <acl-operation> = acl[0];
        if (op = requested-operation)
          for (spec in acl[1])
            // First match wins
            assert(spec.size = 2);
            assert(spec[0] = deny: | spec[0] = allow:);
            let deny? :: <boolean> = (spec[0] = deny:);
            let target = spec[1];
            if (target = $anyone
                  | (user
                       & (target = user
                            | (target = $trusted & user = authenticated-user())
                            | (target = $owner & page.page-owner = user)
                            | (instance?(target, <wiki-group>)
                                 & member?(user, target.group-members)))))
              return(if (deny?) #f else #t end)
            end if;
          end for;
        end if;
      end for;
      #f          // default is no permission if no rule matches
    end block
  end if;
  log-info("has-permission?(%s, %s, %s) => %s",
           user, page, requested-operation, result);
  result
end method has-permission?;

