module: wiki

define object-test (tag) in wiki end;

define function extract-tags
    (tag-string :: <string>)
 => (tags :: <sequence>);
  choose(complement(empty?),
         remove-duplicates!(split(tag-string, " "), test: \=));
end;

define tag show-tag in wiki
 (page :: <wiki-dsp>)
 ()
  if (*tag*)
    output("%s", escape-xml(*tag*));
  end if;
end;

define named-method query-tagged? in wiki
 (page :: <wiki-dsp>)
  get-query-value("tagged");
end;

define body tag list-query-tags in wiki
 (page :: <wiki-dsp>, do-body :: <function>)
 ()
  let tagged = get-query-value("tagged");
  if (instance?(tagged, <string>))
    for (tag in extract-tags(tagged))
      dynamic-bind(*tag* = tag)
        do-body();
      end;
    end for;
  end if;
end;
