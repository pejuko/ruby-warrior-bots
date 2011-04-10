# rubywarrior: universal intermediate bot
# 923 points in normal mode
# 941 points in epic mode
class Player
  DIRECTIONS = [:forward, :right, :backward, :left]

  def initialize
    @health = 20
    @last_move = nil
    @last_bomb = false
    @units = []
    @warrior = nil
    @under_attack = false
    @view = {}
    @enemy = nil
    @detonate = false
  end

  def closer(s1, s2)
    return s2 unless s1
    return s1 if s1[:distance] <= s2[:distance]
    s2
  end

  def check_detonate
    @detonate = false
    DIRECTIONS.each do |dir|
      enemies = 0
      next if @view[dir][0].empty?
      @view[dir].each do |space|
        enemies += 1 if space.enemy?
      end
      if enemies > 1
        @detonate = dir
        @units.each do |u|
          next if u.character != 'C'
          if @warrior.distance_of(u) <= 2
            @enemy = {:distance => 1, :space => @warrior.feel(@detonate), :direction => @detonate}
            @detonate = false
            break
          end
        end if @warrior.respond_to?(:distance_of)
      end
    end

    if (not @detonate) and @last_bomb and @enemies.size > 0
      enemy = false
      @view[@last_bomb][0,2].each {|s| enemy = true if s.enemy?}
      @detonate = @last_bomb if enemy
    end
  end

  def scan_view
    @detonate = @enemy = @captive = @stairs = nil
    DIRECTIONS.each do |dir|
      space = @view[dir].first
      s = {:distance => 1, :direction => dir, :space => space}
      if space.character == 'C'
        @captive = closer @captive, s
      elsif space.enemy? or space.captive?
        @enemy = (not @enemy) ? s : space.captive? ? @enemy : closer(@enemy, s)
      elsif space.stairs?
          @stairs = s
      end
    end
    check_detonate
  end

  def look_around
    DIRECTIONS.each do |dir|
      if @warrior.respond_to? :look
        @view[dir] = @warrior.look(dir)
      elsif @warrior.respond_to? :feel
        @view[dir] = [@warrior.feel(dir)]
      else 
        @view[dir] = []
      end
    end

    if @warrior.respond_to? :listen
      @units = @warrior.listen.sort { |a,b|
        (a.captive? and a.ticking?) ? -1 : 
          (b.captive? and b.ticking?) ? 1 : 0
      }
    end

    @enemies = @units.select{ |u| u.character != 'C' }

    scan_view
  end

  def low_health?
    return false unless @warrior.respond_to?(:health)
    return false if @warrior.respond_to?(:listen) and @enemies.size == 0
    if @enemy
      c = @enemy[:space].character
      lh = @health < 16
      return true if c == 'S' and lh
    end
    @warrior.health < 16
  end

  def under_attack?
    return false
    @under_attack
  end

  def ticking?
    return false if @units.empty?
    @units[0].captive? and @units[0].ticking?
  end

  def surrounded?
    enemies = 0
    captives = 0
    DIRECTIONS.each do |d|
      space = @view[d].first
      enemies += 1 if space and space.enemy?
      captives += 1 if space and space.captive?
    end
    (enemies > 1) or (ticking? and enemies > 0 and captives > 0 and (@captive and @captive[:space].ticking?))
  end

  def oposite?(a,b)
    case a
    when :left
      b == :right
    when :right
      b == :left
    when :forward
      b == :backward
    when :backward
      b == :forward
    end
  end

  def move!(dir=:forward)
    @last_bomb = false
    @last_move = dir
    @warrior.walk! dir
  end

  def no_way?
    dir = nil
    DIRECTIONS.each do |d|
      next unless @warrior.feel(d).empty?
      next if oposite?(@last_move, d)
      dir = d
    end
    dir == nil
  end

  def play_turn(warrior)
    @warrior = warrior

    if @warrior.respond_to?(:health)
      @under_attack = (@warrior.health < @health) and (not @last_bomb)
      @health = @warrior.health
    end

    look_around

    if surrounded?
      dir = @enemy[:direction]
      DIRECTIONS.each do |d|
        s = @view[d][0]
        next if s.empty? or s.wall? or s.captive?
        next if d == @detonate
        next if ticking? and @warrior.respond_to?(:direction_of) and (@warrior.direction_of(@units.first) == d)
        dir = d
      end
      return @warrior.bind!(dir)
    end

    if low_health? and (not @stairs) and (not under_attack?) and (not ticking?)
      if (@warrior.respond_to?(:listen) and @enemies.size > 0) and (not @enemy or @enemy[:space].captive?) or
         (not @enemy) or
         (@enemy and @enemy[:space].captive?)
        return @warrior.rest! 
      end
    end

    if @detonate
      return @warrior.rest! if @warrior.health < 5
      @last_bomb = @detonate
      return @warrior.detonate!(@detonate)
    end

    if @enemy and ((not ticking?) or no_way?)
      if ticking?
        # no way, so bot has to fight
        return @warrior.attack!(@warrior.direction_of @units.first)
      end
      return @warrior.attack!(@enemy[:direction]) if (@enemy[:distance] <= 1)
      return move!(@enemy[:direction])
    end

    if low_health? and @last_bomb and @enemies.size>0
      return @warrior.rest!
    else
      @last_bomb = false
    end

    if @captive and ((not ticking?) or (@captive[:space].ticking?))
      return @warrior.rescue!(@captive[:direction]) if @captive[:distance] <= 1
      return move!(@captive[:direction])
    end

    unless @units.empty?
      dir = @warrior.direction_of(@units.first)
      if @warrior.feel(dir).stairs? or not @warrior.feel(dir).empty?
        pos = []
        DIRECTIONS.each do |d|
          space = @warrior.feel(d)
          next if space.stairs?
          next if not space.empty?
          pos << d
        end
        dir = (oposite?(dir, pos.first) and pos.size > 1) ? pos.last : pos.first
      end
      return move! dir
    end

    move! @warrior.direction_of_stairs
  end
end
