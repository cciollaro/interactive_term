module InteractiveTerm
  class Bitmap
    def self.iterate(bitmap, &block)
      y = 0
      bitmap.each do |str|
        x = 0
        str.each_char do |char|
          yield char, x, y
          x += 1
        end
        y += 1
      end
    end
  end
end
