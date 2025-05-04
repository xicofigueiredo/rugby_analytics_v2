module MatchesHelper
  def get_home_position(num)
    positions = {
      15 => 'left: 45%; top: 22%;',   # Fullback
      14 => 'left: 89%; top: 25%;',  # Right Wing
      13 => 'left: 77%; top: 30%;',  # Outside Center
      12 => 'left: 65%; top: 35%;',  # Inside Center
      11 => 'left: 15%; top: 25%;',  # Left Wing
      10 => 'left: 53%; top: 40%;',  # Fly-half
      9  => 'left: 31%; top: 45%;',  # Scrum-half
      8  => 'left: 31%; top: 60%;',  # Number 8
      7  => 'left: 47%; top: 60%;',  # Openside Flanker
      6  => 'left: 15%; top: 60%;',  # Blindside Flanker
      5  => 'left: 39%; top: 70%;',  # Lock
      4  => 'left: 23%; top: 70%;',  # Lock
      3  => 'left: 47%; top: 80%;',  # Tighthead Prop
      2  => 'left: 31%; top: 80%;',  # Hooker
      1  => 'left: 15%; top: 80%;'   # Loosehead Prop
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
