module MatchesHelper
  def get_home_position(num)
    positions = {
      15 => 'left: 45%; top: 10%;',  # Fullback
      14 => 'left: 15%; top: 20%;',  # Right Wing
      13 => 'left: 35%; top: 25%;',  # Outside Center
      12 => 'left: 55%; top: 25%;',  # Inside Center
      11 => 'left: 75%; top: 20%;',  # Left Wing
      10 => 'left: 45%; top: 35%;',  # Fly-half
      9  => 'left: 45%; top: 45%;',  # Scrum-half
      8  => 'left: 45%; top: 65%;',  # Number 8
      7  => 'left: 65%; top: 55%;',  # Openside Flanker
      6  => 'left: 25%; top: 55%;',  # Blindside Flanker
      5  => 'left: 55%; top: 75%;',  # Lock
      4  => 'left: 35%; top: 75%;',  # Lock
      3  => 'left: 65%; top: 85%;',  # Tighthead Prop
      2  => 'left: 45%; top: 85%;',  # Hooker
      1  => 'left: 25%; top: 85%;'   # Loosehead Prop
    }
    positions[num] || ''
  end

  def get_away_position(num)
    positions = {
      15 => 'right: 45%; top: 10%;',
      14 => 'right: 15%; top: 20%;',
      13 => 'right: 35%; top: 25%;',
      12 => 'right: 55%; top: 25%;',
      11 => 'right: 75%; top: 20%;',
      10 => 'right: 45%; top: 35%;',
      9  => 'right: 45%; top: 45%;',
      8  => 'right: 45%; top: 65%;',
      7  => 'right: 65%; top: 55%;',
      6  => 'right: 25%; top: 55%;',
      5  => 'right: 55%; top: 75%;',
      4  => 'right: 35%; top: 75%;',
      3  => 'right: 65%; top: 85%;',
      2  => 'right: 45%; top: 85%;',
      1  => 'right: 25%; top: 85%;'
    }
    positions[num] || ''
  end
end
