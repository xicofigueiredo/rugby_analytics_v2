module MatchesHelper
  def get_home_position(num)
    positions = {
      15 => 'left: 50%; top: 5%;',   # Fullback
      14 => 'left: 70%; top: 5%;',  # Right Wing
      13 => 'left: 62%; top: 22%;',  # Outside Center
      12 => 'left: 37%; top: 25%;',  # Inside Center
      11 => 'left: 30%; top: 5%;',  # Left Wing
      10 => 'left: 60%; top: 42%;',  # Fly-half
      9  => 'left: 40%; top: 45%;',  # Scrum-half
      8  => 'left: 50%; top: 60%;',  # Number 8
      7  => 'left: 70%; top: 60%;',  # Openside Flanker
      6  => 'left: 30%; top: 60%;',  # Blindside Flanker
      5  => 'left: 60%; top: 75%;',  # Lock
      4  => 'left: 40%; top: 75%;',  # Lock
      3  => 'left: 70%; top: 90%;',  # Tighthead Prop
      2  => 'left: 50%; top: 90%;',  # Hooker
      1  => 'left: 30%; top: 90%;'   # Loosehead Prop
    }
    positions[num] || ''
  end



  RUGBY_POSITIONS = [
    { number: 1, name: "Loosehead Prop" },
    { number: 2, name: "Hooker" },
    { number: 3, name: "Tighthead Prop" },
    { number: 4, name: "Lock" },
    { number: 5, name: "Lock" },
    { number: 6, name: "Blindside Flanker" },
    { number: 7, name: "Openside Flanker" },
    { number: 8, name: "Number 8" },
    { number: 9, name: "Scrum-half" },
    { number: 10, name: "Fly-half" },
    { number: 11, name: "Left Wing" },
    { number: 12, name: "Inside Centre" },
    { number: 13, name: "Outside Centre" },
    { number: 14, name: "Right Wing" },
    { number: 15, name: "Fullback" }
  ]
end
