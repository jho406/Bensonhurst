# Rails

## Setting the content location

On non-GET `visit`s, Breezy uses the response's `content-location` to create the key used to store your props.

This is because when you render in a `create` or `update`, the returned response does not necessarily reflect the url the user should see.

For example, when the user is on `posts/new` and they make a POST request to `posts/`, we may decide to render `posts/new` for any errors you'd like to show.

It is recommended that you set this header in your `create` and `update` methods. If you used the generators, this is done for you.

```ruby
def create
  @post = Post.new(post_params)

  if @post.save
    redirect_to @post, notice: 'Post was successfully created.'
  else
    response.set_header("content-location", new_post_path)
    render :new
  end
end
```

## Rails Flash
Your Rails flash will work as expected. On the React side, you receive the flash in the `props` of your connected component:

```
class PostsIndex extends React.Component {
  render () {
    const {
      flash,
    } = this.props

    ...
  }
}

export default connect(
  mapStateToProps,
  mapDispatchToProps
)(PostsIndex)

```

A few notes about the client's behavior with the flash:
1. When using `data-bz-visit`, all flash in Breezy's redux state will be cleared before the request.
2. when using `data-bz-remote`, the recieved flash will be merged with the current page's flash.


## `redirect_back_with_bzq`
A helper for your controller actions:

```ruby
def create
  redirect_back_with_bzq fallback_url: '/'
end
```

This helper has the same method signature as Rails own `redirect_back`, the difference here is that `redirect_back_with_bzq` will add the existing `bzq` parameter as part of its redirect `location`.

## props_from_form_with
A view helper that will give you the camelized attributes generated by `form_with` that can be used to passed to React. Has the same method signature as `form_with`

```ruby
json.form_props props_from_form_with(
  url: venue_floor_seats_path(venue, floor),
  method: :get,
)
```
