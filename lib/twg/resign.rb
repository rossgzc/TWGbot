require 'twg/plugin'

module TWG
  class Resign < TWG::Plugin
    include Cinch::Plugin

    def self.description
      "For players who find themselves called into reality (ugh)"
    end

    def initialize(*args)
      super
      self.class.match(@lang.t('resign.command'), :method => :resign)
      __register_matchers
    end

    def resign(m)
      return if @game.nil?
      wolves = players_of_role(:wolf)
      player = m.user.to_s
      role = @game.participants[player]
      return if role.nil?
      return if role == :dead

      if @game.state == :signup
        @game.deregister(player)
        @core.devoice(player)
        chansay('resign.unjoined',
          :player => player,
          :count  => @game.participants.count,
          :min    => @game.min_part
        )
        return
      end

      # Let plugins which introduce non-core roles handle anything that
      # might be required from their character dying.
      if not [:normal, :wolf].include?(role)
        hook_async(:hook_special_resignation, 0, nil, player)
      end

      @game.kill(player)
      chansay('resign.announce', :player => player)
      @core.devoice(player)

      # Ask the game if victory conditions will be met by the next state
      # change, given that we have changed the balance.
      if [:wolveswin, :humanswin].include?(@game.check_victory_condition)
        # cancel any pending state change hooks which would continue the game
        [:enter_night, :exit_night, :enter_day, :exit_day].each do |hook|
          hook_cancel(hook)
        end
        # Advanced the game state and trigger the core's victory condition
        # detection so it will announce the end of the game
        @game.next_state
        @core.check_victory_conditions
      end
    end

  end
end
