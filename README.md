# interactive_term
ruby API to help you drop your term into a fresh interactive mode

# installing
`gem install interactive_term`

(more info: https://rubygems.org/gems/interactive_term)

# usage
```
# pong_paddle.rb
require 'interactive_term'

class Paddle < InteractiveTerm::Sprite
  def initialize(x, y)
    bitmap = [
      "┏┓",
      "┃┃",
      "┗┛"
    ]
    super(x, y, bitmap)
  end
 
  def up
    @y -= 1
    @y = 0 if @y < 0
  end

  def down
    @y += 1
    @y = @screen_height - height if @y > @screen_height - height
  end
end

@interactive_term = InteractiveTerm::Term.new(true)

@paddle = Paddle.new(0, 0)
@interactive_term.screen.add_sprite(@paddle)

@interactive_term.register_listener do |key|
  if key == 'k'
    @paddle.up
  elsif key == 'j'
    @paddle.down
  end
end

@interactive_term.loop {}
```

then simply run `ruby pong_paddle.rb`

![](http://i.imgur.com/3g512qx.png)

# building
`gem build interactive_term.gemspec`

# publishing
`gem push interactive_term-0.1.0.gem`


