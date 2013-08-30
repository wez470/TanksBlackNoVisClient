import com.esotericsoftware.kryonet.*; //networking

import procontroll.*; //gamepad input
import net.java.games.input.*; //gamepad input

import javax.swing.JOptionPane; //JOptionPane

import sprites.utils.*; //Sprite
import sprites.*; //Sprite

import java.awt.*; //Rectangle
import java.util.concurrent.*; //ConcurrentHashMap
import java.util.LinkedList; //LinkedList

Client client;
ControllIO controllIO;
ControllDevice controller;
ControllStick turretStick;
ControllStick moveStick;
StopWatch timer;
color backgroundColor = color(213, 189, 122);
color black = color(0, 0, 0);
color[] tankColors = new color[]{color(40, 150, 30), color(220, 150, 30), color(165, 50, 50), color(67, 90, 229)};
color[] tankBackgroundColors = new color[]{color(139, 148, 82), color(186, 154, 84), color(166, 125, 84), color(137, 127, 113)};
ConcurrentHashMap<Integer, Bullet> bullets;
HashMap<Bullet, Integer> bulletIDs;
HashMap<Wall, Integer> wallIDs;
ConcurrentHashMap<Integer, Wall> walls;
ConcurrentHashMap<Integer, Sprite> powerUps;
HashMap<Sprite, Integer> powerUpIDs;
float bulletSpeed;
float deltaTime;
float shotTimer = -1000;
int moveTimer = -20;
int rotateTimer = -20;
float scaleSize; 
float scalePosition;
ClientTank[] tanks;
Score[] scores;
int numPlayers = 0;
boolean stopped = true;
float prevRot = 1000.0;
float prevDirection = 1000.0;
float prevMagnitude = 1000.0;
int controllerUsedTimer = 0;
boolean looking = true;
int timeSinceNotLooking = 0;
int timeSinceLooking = 0;
int imgProcIndex = 20;
LinkedList<Line> tankTrails = new LinkedList<Line>();
LinkedList<Line> bulletTrails = new LinkedList<Line>();
int trailDiam = 20;
int trailTimer = 0;
int bulletTrailTimer = 0;
int powerUpTimer = 0;
PImage powerUpGrey;
PImage powerUpRedGrey;
boolean powerUpTaken = false;
int powerUpTakenIndex = 0;
LinkedList<DeadTank> deadTanks = new LinkedList<DeadTank>();
LinkedList<Network.HitWallMsg> missedWallHits = new LinkedList<Network.HitWallMsg>();
LinkedList<Message> networkMessages = new LinkedList<Message>();
String currentInput = new String();
boolean inputEnabled = false;
boolean drawCircles = false;
boolean drawNotSeenKills = false;
boolean invincible = false;
boolean disattentionOverride = false;
boolean testMode = false;
LinkedList<Integer> blackoutTimes;
int blackoutTimer;
int blackoutDuration;
boolean blackout = false;
boolean saveAfterFrame = false;
int invincibleTimer = 0;

/**
 * Setup the game for play
 */
void setup()
{
  size(800, 600);
  //size((int) (screen.height * 4.0 / 3.0), screen.height);
  
  bullets = new ConcurrentHashMap<Integer, Bullet>();
  bulletIDs = new HashMap<Bullet, Integer>();
  
  scalePosition = height / 600.0;
  scaleSize = height / 2400.0;
  bulletSpeed = 200.0 * scalePosition;
  tanks = new ClientTank[4];
  scores = new Score[4];
  
  timer = new StopWatch();
  blackoutTimer = (int)random(5000, 55000);
  
  setupController();
  setupWalls();
  setupPowerUps();
  setupBlackoutTimes();

  powerUpGrey = loadImage("Images/PowerUpNotLooking.png");
  powerUpRedGrey = loadImage("Images/PowerUpNotLookingReset.png");
  PFont font = loadFont("Mangal-Bold-14.vlw");
  textFont(font);
  
  client = new Client();
  client.start();
  Network.register(client);
  client.addListener(new Listener()
  {
    public void received(Connection connection, Object object)
    {
      if(object instanceof Network.MoveClientMsg)
      {
        processMoveMessage((Network.MoveClientMsg) object);
      }
      else if(object instanceof Network.RotateClientMsg)
      {
        Network.RotateClientMsg rotateMsg = (Network.RotateClientMsg) object;
        int playerNum = rotateMsg.player;
        if(tanks[playerNum - 1] == null)
        {
          tanks[playerNum - 1] = newTank(playerNum);
          numPlayers++;
        }
        tanks[playerNum - 1].tankTurret.setRot(rotateMsg.turretRot);
      }
      else if(object instanceof Network.HitBulletMsg || object instanceof Network.HitWallMsg || object instanceof Network.HitTankMsg || object instanceof Network.HitPowerUpMsg)
      {
        processCollision(object); 
      }
      else if(object instanceof Network.ShootClientMsg)
      {
        createBullet(object);
      }
      else if(object instanceof Network.PowerUpResetMsg)
      {
        powerUpTaken = false;
        setupPowerUps();
      }
      else if(object instanceof Network.PowerUpReceivedMsg)
      {
        powerUpTimer = millis();
      }
      else if(object instanceof Network.InvincibleClientMsg)
      {
        tanks[((Network.InvincibleClientMsg)object).player - 1].invincible = true;
      }
      else if(object instanceof Network.InvincibleStopClientMsg)
      {
        tanks[((Network.InvincibleStopClientMsg)object).player - 1].invincible = false;
      }
      else if(object instanceof Network.ChatMsg)
      {
        synchronized(networkMessages)
        {
          networkMessages.add(new Message(((Network.ChatMsg) object).message));
        }
      }
      else if(object instanceof Network.UpdateClientMsg)
      {
        processUpdateClientMsg((Network.UpdateClientMsg) object);
      }
    }
  });
  String inputIP = JOptionPane.showInputDialog(this, "Enter the IP address to connect to");
  try
  {
    client.connect(5000, inputIP, Network.TCPPort, Network.UDPPort);
  } 
  catch (IOException e) 
  {
    e.printStackTrace();
  }
}

/** 
 * A method to get the current time as a string
 */
String time()
{
  return hour() + "h_" + minute() + "m_" + second() + "s";
}

/**
 * Create a new tank.
 * This method is made for the purpose of accessing "this" (the outer class) from
 * inner classes.
 */
ClientTank newTank(int playerNum)
{
   return new ClientTank(this, scaleSize, playerNum);
}

/**
 * Set up the walls for the game
 */
void setupWalls()
{
  walls = new ConcurrentHashMap<Integer, Wall>();
  wallIDs = new HashMap<Wall, Integer>();
  //walls created top to bottom left to right
  float wallsX[] = {0.77 * width, 0.15 * width, 0.23 * width, 0.31 * width, 0.39 * width, 0.61 * width, 0.69 * width,
                    0.77 * width, 0.85 * width, 0.055 * width, 0.15 * width, 0.23 * width, 0.77 * width, 0.85 * width,
                    0.15 * width, 0.23 * width, 0.77 * width, 0.85 * width, 0.945 * width, 0.15 * width,
                    0.23 * width, 0.31 * width, 0.39 * width, 0.61 * width, 0.69 * width, 0.77 * width, 0.85 * width,
                    0.23 * width};
  float wallsY[] = {0.0867 * height, 0.2267 * height, 0.2267 * height, 0.2267 * height, 0.2267 * height, 0.2267 * height,
                    0.2267 * height, 0.2267 * height, 0.2267 * height, 0.3334 * height, 0.3334 * height, 0.3334 * height,
                    0.3334 * height, 0.3334 * height, 0.6667 * height, 0.6667 * height, 0.6667 * height,
                    0.6667 * height, 0.6667 * height, 0.773 * height, 0.773 * height, 0.773 * height, 0.773 * height, 
                    0.773 * height, 0.773 * height, 0.773 * height, 0.773 * height, 0.913 * height};
  int numWalls = wallsX.length;
  for(int i = 0; i < numWalls; i++)
  {
    Wall wall = new Wall(this, "Images/BlockTiles5Cracked.png", 5, 1, 100);
    wall.setFrame(0);
    wall.setXY(wallsX[i], wallsY[i]);
    wall.setScale(2 * scaleSize);
    walls.put(i + 1, wall);
    wallIDs.put(wall, i + 1);
  }
}

/**
 * Sets up the blackout times
 */
void setupBlackoutTimes()
{
  blackoutTimes = new LinkedList<Integer>();
  blackoutTimes.add(1);
  blackoutTimes.add(5);
  blackoutTimes.add(10);
}

/**
 * Set up the power ups for the game
 */
void setupPowerUps()
{
  powerUps = new ConcurrentHashMap<Integer, Sprite>();
  powerUpIDs = new HashMap<Sprite, Integer>();
  float powerUpsX[] = {0.5};
  float powerUpsY[] = {0.5};
  int numPowerUps = powerUpsX.length;
  for(int i = 0; i < numPowerUps; i++)
  {
    Sprite powerUp = new Sprite(this, "Images/PowerUp.png", 1, 1, 100);
    powerUp.setXY(powerUpsX[i] * width, powerUpsY[i] * height);
    powerUp.setScale(3.75 * scaleSize);
    powerUps.put(i + 1, powerUp);
    powerUpIDs.put(powerUp, i + 1);
  }
}

/**
 * Set up controller
 */
void setupController()
{
  boolean sticks = false;
  boolean sliders = false;
  controllIO = ControllIO.getInstance(this);
  int numDevices = controllIO.getNumberOfDevices();
  //go through all devices and find the first useable controller
  for(int i = 0; i < numDevices; i++)
  {
    int numSticks = controllIO.getDevice(i).getNumberOfSticks();
    int numSliders = controllIO.getDevice(i).getNumberOfSliders();
    if(numSticks == 2)
    {
      //for logitech controllers
      sticks = true;
      controller = controllIO.getDevice(i);
      break;
    }
    else if(numSliders >= 4)
    {
      //for xbox controllers
      sliders = true;
      controller = controllIO.getDevice(i);
      break;
    }
  }
  if(sticks)
  {
    //logitech
    controller.plug(this, "handleRBPress", ControllIO.WHILE_PRESS, 6);
    if(testMode)
    {
      controller.plug(this, "handleLBPress", ControllIO.ON_PRESS, 5);
    }
    turretStick = controller.getStick(0);
    moveStick = controller.getStick(1);
  }
  else if(sliders)
  {
    //xbox
    controller.plug(this, "handleRBPress", ControllIO.WHILE_PRESS, 5);
    if(testMode)
    {
      controller.plug(this, "handleLBPress", ControllIO.ON_PRESS, 4);
    }
    turretStick = new ControllStick(controller.getSlider(3), controller.getSlider(2));
    moveStick = new ControllStick(controller.getSlider(1), controller.getSlider(0));    
  }
}

/**
 * Function to handle shoot requests
 * triggered by right bumper presses
 */
void handleRBPress()
{
  controllerUsedTimer = millis();
  if(!blackout)
  {
    if(millis() - powerUpTimer < 10000)
    {
      if(millis() - shotTimer > 350)
      {
        Network.ShootServerMsg shootMsg = new Network.ShootServerMsg();
        client.sendTCP(shootMsg);
        shotTimer = millis();      
      }
    }
    else
    {
      if(millis() - shotTimer > 700)
      {
        Network.ShootServerMsg shootMsg = new Network.ShootServerMsg();
        client.sendTCP(shootMsg);
        shotTimer = millis();
      }
    }
  }
}

/**
 * Function to handle not looking requests
 * triggered by left bumper presses
 */
void handleLBPress()
{
    disattentionOverride = !disattentionOverride;
}

/**
 * Method for processing MoveClientMsgs
 * @param moveMsg: the move message to be processed
 */
void processMoveMessage(Network.MoveClientMsg moveMsg)
{
  int playerNum = moveMsg.player;
  if(tanks[playerNum - 1] == null)
  {
    tanks[playerNum - 1] = newTank(playerNum);
    numPlayers++;
  }
  tanks[playerNum - 1].tankBase.setXY(moveMsg.x * scalePosition, moveMsg.y * scalePosition);
  tanks[playerNum - 1].tankTurret.setXY(moveMsg.x * scalePosition, moveMsg.y * scalePosition);
  tanks[playerNum - 1].health.x = (int)(moveMsg.x * scalePosition);
  tanks[playerNum - 1].health.y = (int)(moveMsg.y * scalePosition);
  tanks[playerNum - 1].tankBase.setRot(moveMsg.baseRot);
  tanks[playerNum - 1].tankTurret.setRot(moveMsg.turretRot);
}

/**
 * Method to process UpdateClientMsgs
 * @param updateMsg: the update message to be processed
 */
void processUpdateClientMsg(Network.UpdateClientMsg updateMsg)
{
  //update player positions
  for(Network.MoveClientMsg currMoveMsg: updateMsg.playerPositions)
  {
    processMoveMessage(currMoveMsg);
  }
  //create all bullets
  for(Network.ShootClientMsg currShootMsg: updateMsg.bullets)
  {
    createBullet(currShootMsg);
  }
  //update power up
  powerUpTaken = updateMsg.powerUpTaken;
  if(powerUpTaken)
  {
    powerUps = new ConcurrentHashMap<Integer, Sprite>();
    powerUpIDs = new HashMap<Sprite, Integer>();
  }
  //remove destroyed walls
  for(int currWallID: updateMsg.removedWalls)
  {
    Wall currWall = walls.get(currWallID);
    walls.remove(currWallID);
    wallIDs.remove(currWall);
  }
  //update partially destroyed walls
  for(int currWallID: wallIDs.values())
  {
    Wall currWall = walls.get(currWallID);
    currWall.hitCount = updateMsg.wallHits.get(currWallID);
    currWall.setFrame(updateMsg.wallHits.get(currWallID) / 2);
  }
  //update tanks health and scores
  for(int i = 0; i < 4; i++)
  {
    if(tanks[i] != null)
    {
      tanks[i].health.percent = updateMsg.health.get(i);
      scores[i] = new Score(i + 1);
      scores[i].kills = updateMsg.scores.get(i);
    }
  }
}

/**
 * Update and Draw everything in the game
 */
void draw()
{
  if(millis() - blackoutTimer >= 0)
  {
    saveFrame("log/" + time() + ".png");
    blackout = true;
    client.sendTCP(new Network.StopMsg());
    blackoutTimer += 60000;
    int i = min(blackoutTimes.size() - 1, (int)random(0, blackoutTimes.size()));
    blackoutDuration = blackoutTimes.get(i) * 1000 + millis();
    blackoutTimes.remove(i);
    if(blackoutTimes.isEmpty())
    {
      setupBlackoutTimes();
    }
  }
  deltaTime = (float) timer.getElapsedTime();
  if(blackout)
  {
    attentionUpdate();
    background(black);
    if(millis() - blackoutDuration >= 0)
    {
      blackout = false;
      saveAfterFrame = true;
    }
    for(Bullet currBullet: bullets.values())
    {
      currBullet.bullet.update(deltaTime);
    }  
  }
  else
  {
    background(backgroundColor);
    processUserGameInput(deltaTime);
    if(drawCircles)
    {
      ellipseMode(CENTER);
      for(int i = 0; i < 4; i++)
      {
        if(tanks[i] != null)
        {
          noStroke();
          fill(tankBackgroundColors[i]);
//          ellipse((float)tanks[i].tankBase.getX(), (float)tanks[i].tankBase.getY(), 300 * scaleSize, 300 * scaleSize);
          pushMatrix();
          translate((int)tanks[i].tankBase.getX(), (int)tanks[i].tankBase.getY());
          rotate((float)tanks[i].tankTurret.getRot() + PI);
//          rect(-11.0, 0.0, 22, 80.0);
          popMatrix();
        }
      }
    }
    for(int i = 0; i < 4; i++)
    {
      if(tanks[i] != null && tanks[i].invincible)
      {
        ellipseMode(CENTER);
        stroke(0, 140, 255, 255);
        strokeWeight(2);
        fill(0, 0, 0, 0);
        ellipse((float)tanks[i].tankBase.getX(), (float)tanks[i].tankBase.getY(), 350 * scaleSize, 350 * scaleSize);
      }
    }
    for(Line currLine: tankTrails)
    {
//      currLine.draw();
    }
    for(Line currLine: bulletTrails)
    {
//      currLine.draw();
    }
    for(Sprite currPowerUp: powerUps.values())
    {
      currPowerUp.draw();
    }
    if(powerUpTaken && powerUpTakenIndex > 0)
    {
//      image(powerUpGrey, 0.5 * width, 0.5 * height, powerUpGrey.width * 3.75 * scaleSize, powerUpGrey.height * 3.75 * scaleSize);
    }
    else if(!powerUpTaken && powerUpTakenIndex > 0)
    {
//      image(powerUpRedGrey, 0.5 * width, 0.5 * height, powerUpRedGrey.width * 3.75 * scaleSize, powerUpRedGrey.height * 3.75 * scaleSize);
    }
    synchronized(deadTanks)
    {
      for(DeadTank deadTank: deadTanks)
      {
//        deadTank.draw();
      }
    }
    for(int i = 0; i < 4; i++)
    {
      if(tanks[i] != null)
      {
        tanks[i].drawBase();
      }
    }
    for(Wall currWall: walls.values())
    {
      currWall.draw();
    }
    for(int i = 0; i < 4; i++)
    {
      if(tanks[i] != null)
      {
        tanks[i].drawHealth();
      }
    }
    for(int i = 0; i < 4; i++)
    {
      if(tanks[i] != null)
      {
        tanks[i].drawTurret();
      }
    }
    attentionUpdate();
    drawText();
    PriorityQueue<Score> orderedScores = new PriorityQueue<Score>(4);
    for(int i = 0; i < 4; i++)
    {
      if(scores[i] != null)
      {
        orderedScores.add(scores[i]);
      }
    }
    int numScores = numPlayers - 1;
    for(int i = 0; i < 4; i++)
    {
      if(scores[i] != null)
      {
        fill(0, 0, 0, 210);
        textSize(48 * scaleSize);
        textAlign(LEFT);
        if(drawNotSeenKills)
        {
          text(orderedScores.poll().toString(), 4 * scaleSize, height - 16 * scaleSize - 48 * numScores * scaleSize);
        }
        else
        {
          text(orderedScores.poll().toString(), 4 * scaleSize, height - 16 * scaleSize - 48 * numScores * scaleSize);
        }
        numScores--;
      }
    }
    for(Bullet currBullet: bullets.values())
    {
      currBullet.bullet.update(deltaTime);
      currBullet.bullet.draw();
    }  
    if(saveAfterFrame)
    {
      saveFrame("log/" + time() + ".png");
      saveAfterFrame = false;
    }
  }
}

/**
 * Draws the chat text to the screen
 */
void drawText()
{
  if(inputEnabled)
  {
    fill(0, 0, 0, 100);
    stroke(0, 0, 0, 100);
    rect(5 *  scaleSize, 5 * scaleSize, width - 1040 * scaleSize, 60 * scaleSize);
  }
  fill(0);
  textSize(64 * scaleSize);
  textAlign(LEFT);
  //print text buffered from edge
  text(currentInput, 12 * scaleSize, 56 * scaleSize);
  synchronized(networkMessages)
  {
    int i = networkMessages.size() - 1;
    ListIterator<Message> messagesIt = networkMessages.listIterator();
    while(messagesIt.hasNext())
    {
      Message m = messagesIt.next();
      if(m.remove)
      {
        messagesIt.remove();
      }
      else
      {
        m.draw(i);
      }
      i--;
    }
  }
}

/**
 * Method to change what is being drawn depending on if the user is paying attention or not
 */
void attentionUpdate()
{
  if(blackout)
  {
    notLookingTasks();
  }
  else
  {
    lookingTasks();
  }
}

/**
 * Things that need to be done by the program when the user is not looking
 */
void notLookingTasks()
{
  timeSinceNotLooking = millis();
  if(millis() - trailTimer >= 0)
  {
    //if there are no current trails, set previous positions to current 
    //so that we don't draw from old points to new points
    if(tankTrails.size() < 1 )
    {
      for(int i = 0; i < 4; i++)
      {
        if(tanks[i] != null)
        {
          tanks[i].prevX = tanks[i].tankBase.getX();
          tanks[i].prevY = tanks[i].tankBase.getY(); 
        }
      }
    }
    //if there are no current trails, set previous positions to current 
    //so that we don't draw from old points to new points
    if(bulletTrails.size() < 1)
    {
      for(Bullet currBullet: bullets.values())
      {
        currBullet.prevX = (int)currBullet.bullet.getX();
        currBullet.prevY = (int)currBullet.bullet.getY();
      }
    }
    //since the user isn't looking, add lines to show where the tanks are
    for(int i = 0; i < 4; i++)
    {
      if(tanks[i] != null)
      {
        tankTrails.add(new Line((int)tanks[i].prevX, (int)tanks[i].prevY, (int)tanks[i].tankBase.getX(), (int)tanks[i].tankBase.getY(), tankColors[i], (int)(12 * scaleSize)));
        tanks[i].prevX = tanks[i].tankBase.getX();
        tanks[i].prevY = tanks[i].tankBase.getY();
      }
    }
    //since the user isn't looking, add lines to show where the bullets are
    for(Bullet currBullet: bullets.values())
    {
      bulletTrails.add(new Line(currBullet.prevX, currBullet.prevY, (int)currBullet.bullet.getX(), (int)currBullet.bullet.getY(), color(0, 0, 0, 100), (int)(4 * scaleSize)));
      currBullet.prevX = (int)currBullet.bullet.getX();
      currBullet.prevY = (int)currBullet.bullet.getY();
    }
    trailTimer = millis();
    synchronized(networkMessages)
    {
      while(networkMessages.size() > 30)
      {
        networkMessages.removeFirst();
      }
      if(networkMessages.size() > 5)
      {
        for(Message m: networkMessages)
        {
          m.visibleLimit = 10000;
          m.timeVisible = millis();
        }
      }
    }
    if((millis() - timeSinceLooking > 1000 || blackout) && !invincible)
    {
      Network.InvincibleServerMsg invincibleMsg = new Network.InvincibleServerMsg();
      client.sendTCP(invincibleMsg);
      invincible = true;
    }
    if(millis() - timeSinceLooking > 2000)
    {
      drawNotSeenKills = true;
      drawCircles = true;
    }
  }
} 

/**
 * Tasks the program needs to do when the user is looking
 */
void lookingTasks()
{
  timeSinceLooking = millis();
  //equation for finding how fast to remove old images.  Exponential equation so older images get removed faster
  //Doesn't get below 5 so that the tail will continue to be removed when it gets short 
  //Equation:   tankTrails.size() = (removeNumber ^ 3) / 2
  int removeNumber = max(15 * numPlayers, (int) pow(((float) tankTrails.size() * 3.0), (1.0 / 2.0)) * numPlayers);
  //if there are tank trails, keep adding trails so that there is a seemless transition to current gameplay
  if(millis() - trailTimer > 0 && tankTrails.size() > removeNumber + 1)
  {
    for(int i = 0; i < 4; i++)
    {
      if(tanks[i] != null)
      {
        tankTrails.add(new Line((int)tanks[i].prevX, (int)tanks[i].prevY, (int)tanks[i].tankBase.getX(), (int)tanks[i].tankBase.getY(), tankColors[i], (int)(12 * scaleSize)));
        tanks[i].prevX = tanks[i].tankBase.getX();
        tanks[i].prevY = tanks[i].tankBase.getY();
      }
    }
    trailTimer = millis();
  }
  //if there are bullet trails, keeping adding trails so that there is a seemless transition to current gameplay
  if(bulletTrails.size() >  removeNumber + 1)
  {
    for(Bullet currBullet: bullets.values())
    {
      bulletTrails.add(new Line(currBullet.prevX, currBullet.prevY, (int)currBullet.bullet.getX(), (int)currBullet.bullet.getY(), color(0, 0, 0, 100), (int)(4 * scaleSize)));
      currBullet.prevX = (int)currBullet.bullet.getX();
      currBullet.prevY = (int)currBullet.bullet.getY();
    }
  }
  //remove part of tank trails
  for(int i = 0; i < min(removeNumber, tankTrails.size()); i++)
  {
    tankTrails.get(i).opacity -= 30;
    if(tankTrails.get(i).opacity <= 30)
    {
      tankTrails.remove(i);
      powerUpTakenIndex--;
      synchronized(deadTanks)
      {
        ListIterator<DeadTank> deadTanksIt = deadTanks.listIterator(0);
        while(deadTanksIt.hasNext())
        {
          DeadTank currDeadTank = deadTanksIt.next();
          currDeadTank.index--;
          if(currDeadTank.index <= 0)
          {
            deadTanksIt.remove();
          }
          else
          {
            deadTanksIt.set(currDeadTank);
          }
        }
      }
    }
  }
  //remove faster than tank trails
  for(int i = 0; i < min(2 * removeNumber, bulletTrails.size()); i++)
  {
    bulletTrails.get(i).opacity -= 30;
    if(bulletTrails.get(i).opacity <= 30)
    {
      bulletTrails.remove(i);
    }
  }
  bulletTrailTimer = millis();
  //deteriorate all walls that were hit when the user was not looking
  ListIterator<Network.HitWallMsg> wallHitsIt = missedWallHits.listIterator(0);
  while(wallHitsIt.hasNext())
  {
    Network.HitWallMsg hitMsg = wallHitsIt.next();
    Wall hitWall = walls.get(hitMsg.wallID);
    hitWall.hitCount += 1;
    if(hitWall.hitCount % 2 == 0 && hitWall.hitCount < 10)
    {
      hitWall.setFrame(hitWall.getFrame() + 1);
    }
    if(hitWall.hitCount >= 10)
    {
      wallIDs.remove(hitWall);
      walls.remove(hitMsg.wallID);
    }
    wallHitsIt.remove();
  }
  if(millis() - timeSinceNotLooking > 3000)
  {
    drawCircles = false;
    drawNotSeenKills = false;
    for(int i = 0; i < 4; i++)
    {
      if(tanks[i] != null)
      {
        tanks[i].lastSeenHealth = tanks[i].health.percent;

      }
      if(scores[i] != null)
      {
        scores[i].notSeenKills = 0;
      }
    }
  }
  synchronized(networkMessages)
  {
    ListIterator<Message> messageIt = networkMessages.listIterator();
    while(messageIt.hasNext())
    {
      Message m = messageIt.next();
      if(m.visibleLimit != 10000.0 && networkMessages.size() > 5)
      {
        messageIt.remove();
      }
    }
  }
  if(millis() - timeSinceNotLooking > 100 && invincible)
  {
    Network.InvincibleStopServerMsg invincibleStopMsg = new Network.InvincibleStopServerMsg();
    client.sendTCP(invincibleStopMsg);
    invincible = false;
  }
}

/**
 * Process user input during gameplay
 * @param deltaTime elapsed time since last frame (seconds)
 */
void processUserGameInput(float deltaTime) 
{
  //get tank input
  float x = moveStick.getX();
  float y = moveStick.getY();
  
  //tank movement
  if(abs(x) < 0.11 && abs(y) < 0.11) //control stick is approximately at center
  {
    if(!stopped)
    {
      Network.StopMsg stopMsg = new Network.StopMsg();
      client.sendTCP(stopMsg);
      stopped = true;
    }
  }
  else
  {
    controllerUsedTimer = millis();
    stopped = false;
    float currMagnitude = min(1.0, sqrt(sq(x) + sq(y)));
    float currDirection = degrees(atan2(y, x));
    if(abs(prevDirection - currDirection) >= 90.0 && millis() - moveTimer > 10)
    {
      Network.MoveServerMsg moveMsg = new Network.MoveServerMsg();
      moveMsg.magnitude = currMagnitude;
      moveMsg.direction = currDirection;
      client.sendTCP(moveMsg);
      prevMagnitude = currMagnitude;
      prevDirection = currDirection;
      moveTimer = millis();
    }
    if((abs(prevMagnitude - currMagnitude) > 0.2 || abs(prevDirection - currDirection) > 3.0) && millis() - moveTimer > 60)
    {
      Network.MoveServerMsg moveMsg = new Network.MoveServerMsg();
      moveMsg.magnitude = currMagnitude;
      moveMsg.direction = currDirection;
      client.sendUDP(moveMsg);
      prevMagnitude = currMagnitude;
      prevDirection = currDirection;
      moveTimer = millis();
    }
  }

  //get turret input
  x = turretStick.getX();
  y = turretStick.getY();
  
  // Adjust turret direction
  if(abs(x) < 0.6 && abs(y) < 0.6)
  {
    //don't update if little to no movement registered
  }
  else
  {
    controllerUsedTimer = millis();
    float currRot = degrees(atan2(y, x));
    if(abs(currRot - prevRot) > 2.0 && millis() - rotateTimer > 30)
    {
      Network.RotateServerMsg rotateMsg = new Network.RotateServerMsg();
      rotateMsg.turretRot = currRot;
      client.sendUDP(rotateMsg);
      prevRot = currRot;
      rotateTimer = millis();
    } 
  }
}

/**
 * Method for processing collision messages
 */
void processCollision(Object object)
{
  if(object instanceof Network.HitBulletMsg)
  {
    Network.HitBulletMsg hitMsg = (Network.HitBulletMsg) object;
    Bullet hitBullet = bullets.get(hitMsg.bulletID);
    bulletIDs.remove(hitBullet);
    bullets.remove(hitMsg.bulletID);
  }
  else if(object instanceof Network.HitWallMsg)
  {
    Network.HitWallMsg hitMsg = (Network.HitWallMsg) object;
    Bullet hitBullet = bullets.get(hitMsg.bulletID);
    if(looking)
    {
      Wall hitWall = walls.get(hitMsg.wallID);
      hitWall.hitCount += 1;
      if(hitWall.hitCount % 2 == 0 && hitWall.hitCount < 10)
      {
        hitWall.setFrame(hitWall.getFrame() + 1);
      }
      if(hitWall.hitCount >= 10)
      {
        wallIDs.remove(hitWall);
        walls.remove(hitMsg.wallID);
      }
    }
    else
    {
      missedWallHits.add(hitMsg);
    }
    bulletIDs.remove(hitBullet);
    bullets.remove(hitMsg.bulletID);
  }
  else if(object instanceof Network.HitTankMsg)
  {
    Network.HitTankMsg hitMsg = (Network.HitTankMsg) object;
    tanks[hitMsg.player - 1].health.percent -= 20;
    if(!looking)
    {
      if(tanks[hitMsg.player - 1].health.percent <= 0)
      {
        synchronized(deadTanks)
        {
          deadTanks.add(new DeadTank(tanks[hitMsg.player - 1].tankBase.getX(), tanks[hitMsg.player - 1].tankBase.getY(), tankTrails.size(), hitMsg.player));
        }
        tanks[hitMsg.player - 1].health.percent = 100;
        tanks[hitMsg.player - 1].lastSeenHealth = 100;
        scores[hitMsg.shooter - 1].kills++;
        scores[hitMsg.shooter - 1].notSeenKills++;
      }
    }
    else //looking
    {
      tanks[hitMsg.player - 1].lastSeenHealth = tanks[hitMsg.player - 1].health.percent;
      if(tanks[hitMsg.player - 1].health.percent <= 0)
      {
        tanks[hitMsg.player - 1].health.percent = 100;
        tanks[hitMsg.player - 1].lastSeenHealth = 100;
        scores[hitMsg.shooter - 1].kills++;
      }
    }
    Bullet hitBullet = bullets.get(hitMsg.bulletID);
    bulletIDs.remove(hitBullet);
    bullets.remove(hitMsg.bulletID);
  }
  else if(object instanceof Network.HitPowerUpMsg)
  {
    Network.HitPowerUpMsg pUpTakenMsg = (Network.HitPowerUpMsg) object;
    Sprite powerUp = powerUps.get(pUpTakenMsg.powerUpID);
    powerUps.remove(pUpTakenMsg.powerUpID);
    powerUpIDs.remove(powerUp);   
    powerUpTaken = true;
    powerUpTakenIndex = tankTrails.size();
  }
}

/**
 * Method that creates bullets from a received server message
 * @precond: object is a ShootClientMsg
 */
void createBullet(Object object)
{
  Network.ShootClientMsg shootMsg = (Network.ShootClientMsg) object;
  Sprite bullet = new Sprite(this, "Images/Bullet.png", 101);
  bullet.setRot(shootMsg.bulletRot);
  bullet.setSpeed(bulletSpeed, shootMsg.heading);
  bullet.setXY(shootMsg.x * scalePosition, shootMsg.y * scalePosition);
  bullet.setScale(scaleSize);
  Bullet b = new Bullet(bullet);
  bullets.put(shootMsg.bulletID, b);
  bulletIDs.put(b, shootMsg.bulletID);
}

void keyPressed()
{
  //override escape so people don't accidentally exit when try to chat
  if(key == ESC)
  {
    key = 0;
  }
}

void keyTyped()
{
  if(key == '~' || key == '`')
  {
    inputEnabled = !inputEnabled;
    if(!inputEnabled)
    {
      currentInput = "";
    }
    return;
  } 
  if(inputEnabled)
  {
    textSize(64 * scaleSize);
    if(key == ENTER)
    {
      Network.ChatMsg chatMsg = new Network.ChatMsg();
      chatMsg.message = currentInput;
      client.sendTCP(chatMsg);
      currentInput = "";
      inputEnabled = false;
    }
    else if(key == BACKSPACE && currentInput.length() > 0)
    {
      currentInput = currentInput.substring(0, currentInput.length() - 1);
    }
    else if (textWidth(currentInput) < width - 1100 * scaleSize)
    {
      currentInput = currentInput + key;
    }
  }
} 

void exit()
{
  Network.DisconnectMsg disconnectMsg = new Network.DisconnectMsg();
  client.sendTCP(disconnectMsg);
  super.exit();
}
