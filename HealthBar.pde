//A line class for storing lines to draw
class HealthBar
{
  public int x;
  public int y;
  public int percent;

  public HealthBar(int x, int y)
  {
    this.x = x;
    this.y = y;
    percent = 100;
  }

  public void draw(int lastSeenHealth)
  {
    strokeWeight(4 * scaleSize);
    noStroke();
    //draw yellow last seen bar
//    fill(255, 255, 0);
//    rect(x - 25 * scalePosition, y - 45 * scalePosition, lastSeenHealth / 2 * scalePosition, 9 * scalePosition);
    fill(200, 0, 0);
    //draw red health bar
    rect(x - 25 * scalePosition, y - 45 * scalePosition, percent / 2 * scalePosition, 9 * scalePosition);
    stroke(0);
    fill(255, 255, 255, 0);  
    //draw rectangle that encloses health bar
    rect(x - 25 * scalePosition, y - 45 * scalePosition, 50 * scalePosition, 9 * scalePosition);   

  }
}
