---
sid: asdf
testvar: asdf
raiting: asdf
rating: asdf
attributes: dasdf
object_class: asdfa
---
Enter SID: `INPUT[text:sid]`

```mb-code
echo {{sid}}
```


`INPUT[text:rating]`

`VIEW[{rating}][text(renderMarkdown)]`


`INPUT[text:object_class]`
`INPUT[text:attributes]`

`INPUT[text:object_class]`
`INPUT[text:attributes]`

`VIEW[<pre>ldapsearch (objectClass={object_class}) --attributes {attributes}</pre>][text(renderHTML)]`



