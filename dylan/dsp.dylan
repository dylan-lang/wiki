Module: wiki-internal

define taglib wiki () end;

// Represents a DSP maintained in our source code tree. Not to be confused
// with <wiki-page>, which is a user-editable wiki page stored in the database
// by web-framework.
//
define class <wiki-dsp> (<dylan-server-page>)
end;

// For sites that are using the wiki as part of a larger application, this
// provides a way to keep the wiki .dsp files in a separate subdirectory
// rather than being forced to keep them at top-level under the DSP root.
define variable *wiki-dsp-subdirectory* :: <string> = "wiki/";

define method initialize
    (page :: <wiki-dsp>, #rest args, #key source :: <string>)
  apply(next-method, page,
        source: concatenate(*wiki-dsp-subdirectory*, source),
        args)
end;
