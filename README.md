# jsxn (v0.2.1) #

this is just [jsx][jsx] but with maps instead of proplists


### differences from jsx ###

```erlang
1> jsx:decode(<<"{\"library\": \"jsxn\", \"awesome?\": true}">>).
#{<<"awesome?">> => true,<<"library">> => <<"jsxn">>}
```

that's pretty much it. enjoy

**jsxn** is released under the terms of the [MIT][MIT] license

copyright 2010-2013 alisdair sullivan

[jsx]: https://github.com/talentdeficit/jsx
[MIT]: http://www.opensource.org/licenses/mit-license.html
