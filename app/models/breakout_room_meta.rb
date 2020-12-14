class BreakoutRoomMeta < ApplicationRecord
    def self.save(breakout_meta = [])
        BreakoutRoomMeta.transaction do
            breakout_meta.each do |room|
                BreakoutRoomMeta.create(room)
            end
        end
    end
end