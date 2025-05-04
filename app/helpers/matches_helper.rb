module MatchesHelper
  def get_home_position(num)
    positions = {
      15 => 'left: 45%; top: 32%;',   # Fullback
      14 => 'left: 89%; top: 35%;',  # Right Wing
      13 => 'left: 77%; top: 40%;',  # Outside Center
      12 => 'left: 65%; top: 45%;',  # Inside Center
      11 => 'left: 15%; top: 35%;',  # Left Wing
      10 => 'left: 53%; top: 50%;',  # Fly-half
      9  => 'left: 31%; top: 52%;',  # Scrum-half
      8  => 'left: 31%; top: 70%;',  # Number 8
      7  => 'left: 47%; top: 70%;',  # Openside Flanker
      6  => 'left: 15%; top: 70%;',  # Blindside Flanker
      5  => 'left: 39%; top: 80%;',  # Lock
      4  => 'left: 23%; top: 80%;',  # Lock
      3  => 'left: 47%; top: 90%;',  # Tighthead Prop
      2  => 'left: 31%; top: 90%;',  # Hooker
      1  => 'left: 15%; top: 90%;',   # Loosehead Prop
      16 => 'left: 15%; top: 10%;',   # Replacement
      17 => 'left: 25%; top: 10%;',   # Replacement
      18 => 'left: 35%; top: 10%;',   # Replacement
      19 => 'left: 45%; top: 10%;',   # Replacement
      20 => 'left: 55%; top: 10%;',   # Replacement
      21 => 'left: 70%; top: 10%;',   # Replacement
      22 => 'left: 80%; top: 10%;',   # Replacement
      23 => 'left: 90%; top: 10%;'   # Replacement
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
    { number: 15, name: "Fullback" },
    { number: 16, name: "Replacement" },
    { number: 17, name: "Replacement" },
    { number: 18, name: "Replacement" },
    { number: 19, name: "Replacement" },
    { number: 20, name: "Replacement" },
    { number: 21, name: "Replacement" },
    { number: 22, name: "Replacement" },
    { number: 23, name: "Replacement" }
  ]
end
