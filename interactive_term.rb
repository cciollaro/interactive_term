require 'thread'
require 'io/console'

module InteractiveTerm
	class Term
		attr_reader :width, :height, :screen

		def initialize
			@stty_state = @width = @height = @listener_thread = nil
			@listeners = []
			@height, @width = IO.console.winsize

			@screen = VirtualScreen.new(@width, @height)
		end

		def register_listener(&block)
			@listeners << block
		end

		def start_session
			# switch to a new terminal context
			system('tput smcup')

			# hide the cursor
			puts "\e[?25l"

			# clear the screen
			puts "\e[H\e[2J"

			# store the stty state
			@stty_state = `stty -g`

			# raw: keypresses get passed along unprocessed
			# -echo: user doesn't see what they type
			# -icanon: no buffering/delay on keypress
			# isig: enable quit special character (necessary because of raw)
			`stty raw -echo -icanon isig`
			
			@lisen_thread = Thread.new do
				Thread.current.abort_on_exception = true
				loop do
					keypress = $stdin.getc
					@listeners.each {|listener| listener.call(keypress)}
				end
			end

			@render_thread = Thread.new do
				Thread.current.abort_on_exception = true
				loop do
					sleep 1.0/30
					if @screen.need_redraw?
						@screen.update!
					end
				end
			end
		end

		def end_session
			#bring back the cursor
			puts "\e[?25h"
			
			#restore stty
			`stty #{@stty_state}`
			
			#return to original terminal context
			system('tput rmcup')
		end
		
		def debug!
			unless @debug
				@listeners << proc {|key| @screen.draw(key, width, height-1)}
				@debug = true
			end
		end
	end

	class Bitmap
		def self.iterate(bitmap, &block)
			x = y = 0
			bitmap.each do |str|
				str.each_char do |char|
					yield char, x, y
					x += 1
				end
				y += 1
			end
		end
	end

	class Sprite
		attr_reader :x, :y, :bitmap, :needs_redraw

		# bitmap is an array of strings. 
		# (x,y) is the position of the first character.
		# each string represents the next line.
		# newlines in bitmap is undefined behavior.
		def initialize(x, y, bitmap)
			@x = x
			@y = y
			@bitmap = bitmap

			@prev_x = nil
			@prev_y = nil
			@prev_bitmap = nil
			#@state_mutex = Mutex.new
		end

		def x=(new_x)
			return if new_x == @x

			@prev_x = @x
			@x = new_x
			@needs_redraw = true
		end

		def y=(new_y)
			return if new_y == @y

			@prev_y = @y
			@y = new_y
			@needs_redraw = true
		end
	 
		def bitmap=(new_bitmap)
			return if new_bitmap == @bitmap

			@prev_bitmap = @bitmap
			@bitmap = new_bitmap
			@needs_redraw = true
		end

		def deltas
			res = []
			
			# clear old sprite
			Bitmap.iterate(@prev_bitmap) do |b_char, b_x, b_y|
				res << [" ", @x + b_x, @y + b_y]
			end

			# draw new sprite
			Bitmap.iterate(@bitmap) do |b_char, b_x, b_y|
				res << [b_char, @x + b_x, @y + b_y]
			end

			res
		end

		def drawn!
			@needs_redraw = false
		end

		def needs_redraw?
			@needs_redraw
		end
	end

	class VirtualScreen
		attr_reader :sprites

		def initialize(width, height)
			@width = width
			@height = height

			@sprites = []

			@draw_mutex = Mutex.new
		end

		def add_sprite(sprite)
			@sprites << sprite
		end
	 
		def need_redraw?
			@sprites.any?(&:needs_redraw?)
		end
	 
		def update!
			@sprites.each do |sprite|
				sprite.deltas.each do |delta|
					self.draw(*delta)
				end
				sprite.drawn!
			end
		end
	 
		def draw(char, x, y)
			raise "stop that" if char.length != 1
			@draw_mutex.synchronize do
				puts "\e[#{y};#{x}H#{char}"
			end
		end

		def cleanup
			@draw_mutex.unlock if @draw_mutex.locked?
			#TODO: might want to do a full clean up of screen here
		end

	end
end
