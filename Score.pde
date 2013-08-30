public class Score implements Comparable<Score>
{
  public int player;
  public int kills;
  public int notSeenKills;
  
  public Score(int p)
  {
    player = p;
    kills = 0;
    notSeenKills = 0;
  }
  
  public int compareTo(Score other)
  {
    return other.kills - this.kills;
  }
  
  public String toString()
  {
    return "Player " + player + ": " + kills; 
  }
}
