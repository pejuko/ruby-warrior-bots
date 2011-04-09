# draft
# score: 925
# epic mode: 924
class Player
  DIRECTIONS = [:forward, :right, :backward, :left]
  RANGE_ENEMY = ['a', 'w']

  def initialize
    @max_health = @health = 20
    @last_move = nil
    @last_bomb = false
    @units = []
    @warrior = nil
    @under_attack = false
    @view = {}
    @enemy = nil
    @left_wall = false
    @detonate = false
  end

  def closer(s1, s2)
    return s2 unless s1
    return s1 if s1[:distance] <= s2[:distance]
    s2
  end

  def scan_view
    @detonate = @enemy = @captive = @stairs = nil
    DIRECTIONS.each do |dir|
      distance = 0
      @view[dir].each do |space|
        distance += 1
        next if distance > 1 and not @warrior.respond_to?(:shoot)
        enemies = 0
        s = {:distance => distance, :direction => dir, :space => space}
        if space.captive?
          @captive = closer @captive, s
        elsif space.enemy?
          unless @enemy
            @enemy = s
          else
            if RANGE_ENEMY.include?(space.character)
              @enemy = RANGE_ENEMY.include?(@enemy[:space].character) ? closer(@enemy, s) : s
            else
              @enemy =  closer @enemy, s
            end
          end
        elsif space.stairs?
          @stairs = s
        end
        break if space.captive? or space.enemy?
      end
    end
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
            p @warrior.distance_of(u)
            @enemy = {:distance => 1, :space => @warrior.feel(@detonate), :direction => @detonate}
            @detonate = false
            break
          end
        end
      end
    end
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

    scan_view
  end

  def wall?(dir=:forward)
    @view[dir].each do |space|
      return true if space.wall?
      return false unless space.empty?
      return false if space.stairs?
    end
    false
  end

  def danger_enemy?
    return false unless @enemy

    c = @enemy[:space].character
    return true if c == 'w'
    return true if c == 'S' and @health < 13
    return true if c == 'a' and (@enemy[:distance] > 2 or @health < 10)
    false
  end

  def low_health?
    return false unless @warrior.respond_to?(:health)
    if @enemy
      c = @enemy[:space].character
      lh = @health < 16
      return true if c == 'S' and lh
    end
    @warrior.health < 16
  end

  def under_attack?
    return true if @under_attack
    if @enemy
      c = @enemy[:space].character
      return true if ['w','a'].include?(c)
    end
    false
  end

  def surrounded?
    enemies = 0
    captives = 0
    DIRECTIONS.each do |d|
      space = @view[d].first
      enemies += 1 if space and space.enemy?
      captives += 1 if space and space.captive?
    end
    (enemies > 1) or (enemies > 0 and captives > 0 and @warrior.health < 5)
  end

  def ticking?
    return false if @units.empty?
    @units[0].captive? and @units[0].ticking?
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
      @under_attack = @warrior.health < @health
      @health = @warrior.health
    end

    look_around

    if low_health? and (not @stairs) and (not under_attack?) and (@units.size > 0) and (not ticking?)
      return @warrior.rest! 
    end

    if surrounded?
      dir = @enemy[:direction]
      DIRECTIONS.each do |d|
        s = @view[d][0]
        next if s.empty? or s.wall? or s.captive?
        next if d == @detonate
        next if ticking? and (@warrior.direction_of(@units.first) == d)
        dir = @warrior.direction_of(s)
      end
      return @warrior.bind!(dir)
    end

    if @enemy and ((not ticking?) or no_way?) and not @detonate
      if ticking?
        return @warrior.attack!(@warrior.direction_of @units.first)
      end
      return @warrior.shoot!(@enemy[:direction]) if (@enemy[:distance] > 1) and danger_enemy?
      return @warrior.attack!(@enemy[:direction]) if (@enemy[:distance] <= 1)
      return move!(@enemy[:direction])
    end

    if @detonate
      return @warrior.rest! if @warrior.health < 5
      @last_bomb = true
      return @warrior.detonate!(@detonate)
    end

    if low_health? and @last_bomb == true and @units.select{|u| u.enemy?}.size>0
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
        if oposite?(dir, pos.first) and pos.size > 1
          dir = pos.last
        else
          dir = pos.first
        end
      end
      return move! dir
    end

    move! @warrior.direction_of_stairs
  end
end
