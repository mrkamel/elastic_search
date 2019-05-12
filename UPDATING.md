
# Updating from previous SearchFlip versions

## Update 1.x to 2.x

* **[BREAKING]** No longer include the `type_name` in `SearchFlip::Index.mapping`

1.x:

```ruby
class MyIndex
  include SearchFlip::Index

  # ...

  def self.mapping
    {
      type_name: {
        properties: {
          # ...
        }
      }
    }
  end
end
```

2.x:

```ruby
class MyIndex
  include SearchFlip::Index

  # ...

  def self.mapping
    {
      properties: {
        # ...
      }
    }
  end
end
```

* **[BREAKING]** Changed `SearchFlip::Index.base_url` to `SearchFlip::Index.connection`

1.x:

```ruby
class MyIndex
  include SearchFlip::Index

  # ...

  def self.base_url
    "..."
  end
end
```

2.x:

```ruby
class MyIndex
  include SearchFlip::Index

  # ...

  def self connection
    @connection ||= SearchFlip::Connection.new(base_url: "...")
  end
end
```

* **[BREAKING]** Changed `SearchFlip.version` to `SearchFlip::Connection#version`

1.x:

```ruby
SearchFlip.version
```

2.x:

```ruby
MyIndex.connection.version

# or

connection = SearchFlip::Connection.new(base_url: "...")
connection.version
```

* **[BREAKING]** Changed `SearchFlip.aliases` to `SearchFlip::Connection#update_aliases`

1.x:

```ruby
SearchFlip.aliases(actions: [
  # ...
])
```

2.x:

```ruby
MyIndex.connection.update_aliases(actions: [
  # ...
])

# or

connection = SearchFlip::Connection.new(base_url: "...")
connection.update_aliases(actions: [
  # ...
])
```

* **[BREAKING]** Changed `SearchFlip.msearch` to `SearchFlip::Connection#msearch`

1.x:

```ruby
SearchFlip.msearch(queries)
```

2.x:

```ruby
MyIndex.connection.msearch(queries)

# or

connection = SearchFlip::Connection.new(base_url: "...")
connection.msearch(queries)
```

* **[BREAKING]** Removed `base_url` param from `SearchFlip::Critiera#execute`

1.x:

```ruby
MyIndex.where(id: 1).execute(base_url: "...")
```

2.x:

```ruby
connection = SearchFlip::Connection.new(base_url: "...")
MyIndex.where(id: 1).with_settings(connection: connection).execute
```

* **[BREAKING]** Move hit data within results in `_hit` namespace

1.x:

```ruby
query = CommentIndex.highlight(:title).search("hello")
query.results[0].highlight.title # => "<em>hello</em> world"
```

2.x:

```ruby
query = CommentIndex.highlight(:title).search("hello")
query.results[0]._hit.highlight.title # => "<em>hello</em> world"
```

* **[BREAKING]** `index_name` no longer defaults to `type_name`

1.x:

```ruby
class CommentIndex
  include SearchFlip::Index

  def self.type_name
    "comments"
  end

  # CommentIndex.index_name defaults to CommentIndex.type_name
end
```

2.x:

```ruby
class CommentIndex
  include SearchFlip::Index

  def self.type_name
    "comments"
  end

  def self.index_name
    "comments"
  end
end
```

* **[BREAKING]** Multiple calls to `source` no longer concatenate

1.x:

```ruby
CommentIndex.source([:id]).source([:description]) # => CommentIndex.source([:id, :description])
```

2.x:

```ruby
CommentIndex.source([:id]).source([:description]) # => CommentIndex.source([:description])
```
