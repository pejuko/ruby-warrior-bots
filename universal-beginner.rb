# rubywarrior: universal beginner bot
# 574 points in normal mode
# 633 points in epic mode

class Player

  DIRECTIONS = [:forward, :backward]
  RANGE_ENEMY = ['a', 'w']

  def initialize
    @max_health = @health = 20
    @warrior = nil
    @under_attack = false
    @view = {}
    @enemy = nil
    @left_wall = false
  end

  def closer(s1, s2)
    return s2 unless s1
    return s1 if s1[:distance] <= s2[:distance]
    s2
  end

  def scan_view
    @enemy = @captive = @stairs = nil
    DIRECTIONS.each do |dir|
      distance = 0
      @view[dir].each do |space|
        distance += 1
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

    scan_view
    @left_wall = true unless @warrior.respond_to?(:feel)
    @left_wall = wall?(:backward) unless @left_wall
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
      lh = @health < 14
      return true if c == 'S' and lh
    end
    @warrior.respond_to?(:look) ? @warrior.health < 7 : @warrior.health < 14
  end

  def under_attack?
    return true if @under_attack
    if @enemy
      c = @enemy[:space].character
      return true if ['w','a'].include?(c)
    end
    false
  end

  def run!
    @warrior.walk! :backward
  end

  def play_turn(warrior)
    @warrior = warrior

    if @warrior.respond_to?(:health)
      @under_attack = @warrior.health < @health
      @health = @warrior.health
    end

    look_around

    if @captive
      return @warrior.rescue!(@captive[:direction]) if @captive[:distance] <= 1
      return @warrior.walk!(@captive[:direction])
    end

    return @warrior.pivot! if wall?
    if low_health? and (not @stairs) and (not under_attack?)
      return @warrior.rest! 
    end

    if @enemy
      return @warrior.shoot!(@enemy[:direction]) if (@enemy[:distance] > 1) and danger_enemy?
      return @warrior.attack!(@enemy[:direction]) if (@enemy[:distance] <= 1)
      return @warrior.walk!(@enemy[:direction])
    end

    return run! if @under_attack and (@health < 7)

    return @warrior.walk!(:backward) unless @warrior.respond_to?(:look) or @left_wall

    @warrior.walk!
  end

end
