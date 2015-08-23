require 'thread'
require 'io/console'

module InteractiveTerm
  class Term
    attr_reader :width, :height, :screen

    def initialize(start_session = false)
      @stty_state = @width = @height = @listener_thread = @session_active = @loop_active = nil
      @listeners = []
      @keypress_queue = Queue.new
      @height, @width = IO.console.winsize

      @screen = InteractiveTerm::Screen.new(@width, @height)

      self.start_session if start_session
    end

    def register_listener(&block)
      @listeners << block
    end

    def start_session
      @session_active = true

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
          @keypress_queue.push $stdin.getc
        end
      end

      trap("SIGINT") do 
        self.end_session
      end
    end

    def loop(&block)
      @loop_active = true

      while @loop_active 
        # process up to 5 keypresses (should be fine because happens 60 times per second)
        begin
          5.times do
            keypress = @keypress_queue.pop(true) #nonblock
            @listeners.each {|listener| listener.call(keypress)} if keypress
          end
        rescue ThreadError # nothing to pop
        end
          
        # run loop code
        yield

        # run render code
        if @screen.need_redraw?
          @screen.update!
        end
        
        sleep 1.0/60
      end
    end

    def break_loop
      @loop_active = false
    end

    def end_session
      sleep 1
      #bring back the cursor
      puts "\e[?25h"
      
      #restore stty
      `stty #{@stty_state}`
      
      #return to original terminal context
      system('tput rmcup')

      @session_active = false
      @loop_active = false
    end
    
    def debug!
      unless @debug
        @listeners << proc {|key| @screen.draw(key, width, height-1)}
        @debug = true
      end
    end
  end
end
