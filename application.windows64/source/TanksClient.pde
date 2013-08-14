import com.esotericsoftware.kryonet.*; //networking

import procontroll.*; //gamepad input
import net.java.games.input.*; //gamepad input

import javax.swing.JOptionPane; //JOptionPane

import sprites.utils.*; //Sprite
import sprites.*; //Sprite

import SimpleOpenNI.*; //Kinect
import monclubelec.javacvPro.*; //Opencv
import java.awt.*; //Rectangle
import java.util.concurrent.*; //ConcurrentHashMap
import java.util.ArrayList; //ArrayList

Client client;
ControllIO controllIO;
ControllDevice controller;
ControllStick turretStick;
ControllStick moveStick;
StopWatch timer;
color backgroundColor = color(213, 189, 122);
ConcurrentHashMap<Integer, Sprite> bullets;
HashMap<Sprite, Integer> bulletIDs;
HashMap<Wall, Integer> wallIDs;
ConcurrentHashMap<Integer, Wall> walls;
float bulletSpeed;
float deltaTime;
float shotTimer = -1000;
int moveTimer = -20;
int rotateTimer = -20;
float scaleSize; 
float scalePosition;
ClientTank[] tanks;
boolean stopped = true;
float prevRot = 1000.0;
float prevDirection = 1000.0;
float prevMagnitude = 1000.0;
int controllerUsedTimer = 0;
SimpleOpenNI cam;
OpenCV opencv; 
ImageProcessingThread imgProcThread;
boolean waiting = true;
Rectangle[] faceRect;
int currNumFaces = 0;
int imgProcIndex = 20;
//ArrayList<Circle> trails = new ArrayList<Circle>();
ArrayList<Line> trails = new ArrayList<Line>();
int trailDiam = 20;
int trailTimer = 0;

/**
 * Setup the game for play
 */
void setup()
{
  size(800, 600);
  //size((int) (screen.height * 4.0 / 3.0), screen.height);
  
  cam = new SimpleOpenNI(this); //initialize kinect camera
  cam.setMirror(true);
  cam.enableRGB();
  opencv = new OpenCV(this);
  opencv.allocate(cam.rgbWidth(), cam.rgbHeight()); //size of image buffer
  opencv.cascade("C:/opencv/data/haarcascades/", "haarcascade_frontalface_alt_tree.xml"); //initialize detection of face
  imgProcThread = new ImageProcessingThread();
  imgProcThread.setPriority(Thread.MIN_PRIORITY);
  imgProcThread.start();
  
  bullets = new ConcurrentHashMap<Integer, Sprite>();
  bulletIDs = new HashMap<Sprite, Integer>();
  
  scalePosition = height / 600.0;
  scaleSize = height / 2400.0;
  bulletSpeed = 300.0 * scalePosition;
  tanks = new ClientTank[4];
  
  timer = new StopWatch();
  
  setupController();
  setupWalls();
  
  client = new Client();
  client.start();
  Network.register(client);
  client.addListener(new Listener()
  {
    public void received(Connection connection, Object object)
    {
      if(object instanceof Network.MoveClientMsg)
      {
        Network.MoveClientMsg moveMsg = (Network.MoveClientMsg) object;
        int playerNum = moveMsg.player;
        if(tanks[playerNum - 1] == null)
        {
          tanks[playerNum - 1] = newTank();
        }
        tanks[playerNum - 1].tankBase.setXY(moveMsg.x * scalePosition, moveMsg.y * scalePosition);
        tanks[playerNum - 1].tankTurret.setXY(moveMsg.x * scalePosition, moveMsg.y * scalePosition);
        tanks[playerNum - 1].tankBase.setRot(moveMsg.baseRot);
        tanks[playerNum - 1].tankTurret.setRot(moveMsg.turretRot);
      }
      else if(object instanceof Network.RotateClientMsg)
      {
        Network.RotateClientMsg rotateMsg = (Network.RotateClientMsg) object;
        int playerNum = rotateMsg.player;
        tanks[playerNum - 1].tankTurret.setRot(rotateMsg.turretRot);
      }
      else if(object instanceof Network.HitBulletMsg || object instanceof Network.HitWallMsg || object instanceof Network.HitTankMsg)
      {
        processCollision(object); 
      }
      else if(object instanceof Network.ShootClientMsg)
      {
        createBullet(object);
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
 * Create a new tank.
 * This method is made for the purpose of accessing "this" (the outer class) from
 * inner classes.
 */
ClientTank newTank()
{
   return new ClientTank(this, scaleSize);
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
                    0.5 * width, 0.15 * width, 0.23 * width, 0.77 * width, 0.85 * width, 0.945 * width, 0.15 * width,
                    0.23 * width, 0.31 * width, 0.39 * width, 0.61 * width, 0.69 * width, 0.77 * width, 0.85 * width,
                    0.23 * width};
  float wallsY[] = {0.0867 * height, 0.2267 * height, 0.2267 * height, 0.2267 * height, 0.2267 * height, 0.2267 * height,
                    0.2267 * height, 0.2267 * height, 0.2267 * height, 0.3334 * height, 0.3334 * height, 0.3334 * height,
                    0.3334 * height, 0.3334 * height, 0.5 * height, 0.6667 * height, 0.6667 * height, 0.6667 * height,
                    0.6667 * height, 0.6667 * height, 0.773 * height, 0.773 * height, 0.773 * height, 0.773 * height, 
                    0.773 * height, 0.773 * height, 0.773 * height, 0.773 * height, 0.913 * height};
  int numWalls = 29;
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
    controller.plug(this, "handleRBPress", ControllIO.WHILE_PRESS, 6);
    turretStick = controller.getStick(0);
    moveStick = controller.getStick(1);
  }
  else if(sliders)
  {
    controller.plug(this, "handleRBPress", ControllIO.WHILE_PRESS, 5);
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
  if(millis() - shotTimer > 700)
  {
    Network.ShootServerMsg shootMsg = new Network.ShootServerMsg();
    client.sendTCP(shootMsg);
    shotTimer = millis();
  }
}

/**
 * Update and Draw everything in the game
 */
void draw()
{
  deltaTime = (float) timer.getElapsedTime();
  background(backgroundColor);
  processUserGameInput(deltaTime);
  for(Line currLine: trails)
  {
    currLine.drawLine();
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
      tanks[i].drawTurret();
    }
  }
  for(Sprite currBullet: bullets.values())
  {
    currBullet.update(deltaTime);
    currBullet.draw();
  }  
  if(imgProcIndex >= 20 && waiting)
  {
    synchronized(imgProcThread)
    {
      imgProcThread.notify();
    }
    imgProcIndex = 0;
  }
  else
  {
    imgProcIndex++;
  }
  attentionCalculation();
}

/**
 * Method to change what is being drawn depending on if the user is paying attention or not
 */
void attentionCalculation()
{
  if(getCurrNumFaces() < 1)
  {
    //not looking
    if(millis() - trailTimer >= 0)
    {
      for(int i = 0; i < 4; i++)
      {
        if(tanks[i] != null)
        {
          if(trails.size() < 1)
          {
            tanks[i].prevX = tanks[i].tankBase.getX();
            tanks[i].prevY = tanks[i].tankBase.getY();
          }
          trails.add(new Line((int)tanks[i].prevX, (int)tanks[i].prevY, (int)tanks[i].tankBase.getX(), (int)tanks[i].tankBase.getY(), color(40, 150, 30)));
          tanks[i].prevX = tanks[i].tankBase.getX();
          tanks[i].prevY = tanks[i].tankBase.getY();
        }
      }
      trailTimer = millis();
    }
  }
  else
  {
    //equation for finding how fast to remove old images.  Exponential equation so older images get removed faster
    //Doesn't get below 5 so that the tail will continue to be removed when it gets short 
    //Equation:   trails.size() = (removeNumber ^ 2) / 2
    int removeNumber = max(15, (int) pow(((float) trails.size() * 3.0), (1.0 / 2.0)));
    if(millis() - trailTimer > 0 && trails.size() > removeNumber + 1)
    {
      for(int i = 0; i < 4; i++)
      {
        if(tanks[i] != null)
        {
          trails.add(new Line((int)tanks[i].prevX, (int)tanks[i].prevY, (int)tanks[i].tankBase.getX(), (int)tanks[i].tankBase.getY(), color(40, 150, 30)));
          tanks[i].prevX = tanks[i].tankBase.getX();
          tanks[i].prevY = tanks[i].tankBase.getY();
        }
      }
      trailTimer = millis();
    }
    for(int i = 0; i < min(removeNumber, trails.size()); i++)
    {
      trails.get(i).opacity -= 30;
      if(trails.get(i).opacity <= 30)
      {
        trails.remove(i);
      }
    }
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
    Sprite hitBullet = bullets.get(hitMsg.bulletID);
    bulletIDs.remove(hitBullet);
    bullets.remove(hitMsg.bulletID);
  }
  else if(object instanceof Network.HitWallMsg)
  {
    Network.HitWallMsg hitMsg = (Network.HitWallMsg) object;
    Sprite hitBullet = bullets.get(hitMsg.bulletID);
    Wall hitWall = walls.get(hitMsg.wallID);
    hitWall.hitCount++;
    if(hitWall.hitCount % 2 == 0 && hitWall.hitCount < 10)
    {
      hitWall.setFrame(hitWall.getFrame() + 1);
    }
    if(hitWall.hitCount >= 10)
    {
      wallIDs.remove(hitWall);
      walls.remove(hitMsg.wallID);
    }
    bulletIDs.remove(hitBullet);
    bullets.remove(hitMsg.bulletID);
  }
  else if(object instanceof Network.HitTankMsg)
  {
    Network.HitTankMsg hitMsg = (Network.HitTankMsg) object;
    //tanks[hitMsg.player - 1] = null;
    Sprite hitBullet = bullets.get(hitMsg.bulletID);
    bulletIDs.remove(hitBullet);
    bullets.remove(hitMsg.bulletID);
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
  bullets.put(shootMsg.bulletID, bullet);
  bulletIDs.put(bullet, shootMsg.bulletID);
}

synchronized int getCurrNumFaces()
{
  return currNumFaces;
}
  
  
synchronized void setCurrNumFaces(int faces)
{
  currNumFaces = faces;
}

void exit()
{
  Network.DisconnectMsg disconnectMsg = new Network.DisconnectMsg();
  client.sendTCP(disconnectMsg);
  super.exit();
}