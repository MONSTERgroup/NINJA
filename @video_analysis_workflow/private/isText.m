function is_text = isText(text)
%ISTEXT Silly helper function that made text processing easier.

is_text = 1*ischar(text) + 2*isstring(text) + 3*iscellstr(text);

end