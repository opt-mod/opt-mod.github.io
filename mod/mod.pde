import java.util.Arrays;

int total_vie = 50;
int total_hub = 10;
double vie_speed = 10;

double[][][] arrival_rate;

HubC hub;

int currentTime = 0;
String[] info;

int[] lostC;

int ttotal = 0;

int clost = 0;
int cycle = 0;


void setup() {
  randomSeed(0);
  size(1120, 880, P2D);
  hub = new HubC(total_hub, total_vie);

  arrival_rate = new double[1440][total_hub][total_hub];
  for (int i = 0; i < 1440; i++) {
    for (int j = 0; j < total_hub; j++) {
      for (int k = 0; k < total_hub; k++) {
        if (j == k) {
          arrival_rate[i][j][k] = 0;
        }
        else {
          arrival_rate[i][j][k] = 0.010 * random(0,1);
        }
      }
    }
    
  }
  lostC = new int[total_hub];
  for (int i = 0; i < total_hub; i++) {
    lostC[i] = 0;
  }
  clost = 0;
  ttotal = 0;

  info = new String[total_hub];
  for (int i = 0; i < total_hub; i++) {
    info[i] = " ";
  }
}


void draw() {
  background(255);
  fill(0);
  stroke(0);


  pushMatrix();
  translate(40,40);

  // Draw edges
  for (int i = 0; i < total_hub; i++) {
    for (int j = i+1; j < total_hub; j++) {
      strokeWeight(2);
      fill(60, 160);
      stroke(180, 160);
      line(hub.locations[i].x, hub.locations[i].y, hub.locations[j].x, hub.locations[j].y);
    }
  }

  int highlighted = displayHUD();
  textSize(24);
  text("Lost consumers: " + clost, 20, 20);
  text("Total Trips: " + ttotal, 20, 50);
  text("Lost percentage: " + String.format("%.2f", clost*100.0/ttotal) + "%", 20, 80);
  // Draw vertices
  for (int i = 0; i < total_hub; i++) {
    PVector a = hub.locations[i];
    stroke(20, 240);
    fill(40);
    if (highlighted == i) {
      fill(200, 80, 0, 180);
      stroke(40, 180);
    }
    ellipse(a.x, a.y, 5+hub.viecles[i][i], 5+hub.viecles[i][i]);
    textSize(18);
    text(lostC[i],a.x+2+hub.viecles[i][i], a.y-2-hub.viecles[i][i]);
  }

  update();

  for (Trip a : hub.trips) {
    a.render();
  }
  //printInfo();
  popMatrix();
}

int displayHUD() {
  double minDis = 10000;
  int selectedL = -1;
  double curDis = 0;
  for (int i = 0; i < total_hub; i++) {
    curDis = distance(new PVector(mouseX-40, mouseY-40), hub.locations[i]);
    if (curDis < minDis) {
      selectedL = i;
      minDis = curDis;
    }
  }
  if (selectedL > -1 && minDis < 50) {
    pushMatrix();
    translate(840,0);
    text("Selected Hub ID: " + selectedL, 0, 0);



    popMatrix();
    return selectedL;
  }
  return -1;
}



void printInfo() {
  textSize(32);
  for(int i = 0; i < total_hub; i++) {
    text(info[i], 100.0f, 100.0f + 40*i);
  }
  text(clost + " " + cycle, 500, 100);
}

double[] lp() {
  double[] objfn = new double[total_hub * total_hub];
  for (int i = 0; i < total_hub; i ++) {
    for (int j = 0; j < total_hub; j ++) {
      objfn[i*total_hub + j] = hub.dis[i][j];
    }
  }
  LinearProgram lp = new LinearProgram(objfn);
  
  String cons = "c";

  int total_Q = 0;
  int total_free = 0;

  for (int i = 0; i < total_hub; i++) {
    total_free += hub.viecles[i][i];
  }

  int ave = floor(total_free/total_hub);

  for (int i = 0; i < total_hub; i++){
    total_Q += hub.waitings[i].size();
    if (hub.viecles[i][i] - hub.waitings[i].size() <= floor(ave/2)) {
      total_Q += floor(ave/2) - hub.viecles[i][i];
    }
  }
  total_Q += 1;

  for (int i = 0; i < total_hub; i ++) {
    double[] curCons = new double[total_hub*total_hub];
    for (int j = 0; j < total_hub * total_hub; j++) {
      curCons[j] = 0;
    }
    for (int j = 0; j < total_hub; j ++) {
      curCons[i*total_hub + j] = -1;
      curCons[j*total_hub + i] = 1;
    }
    for(int j = 0; j < total_hub; j ++) {
      curCons[j*total_hub + j] = 0;
    }

    double curV = hub.waitings[i].size() - hub.viecles[i][i] + ave/2;

    if (total_Q > total_free) {
      curV = floor(total_free * (hub.waitings[i].size() + ave/2) / total_Q) - hub.viecles[i][i];
    }
 
    info[i] = (float)curV + " s" + hub.waitings[i].size() + " v" + hub.viecles[i][i];

    lp.addConstraint(new LinearBiggerThanEqualsConstraint(curCons, curV, cons + i));
  }
  for (int j = 0; j < total_hub * total_hub; j++) {
    double[] curCons = new double[total_hub*total_hub];
    for (int k = 0; k < total_hub * total_hub; k++) {
      curCons[k] = 0;
    }
    curCons[j] = 1;
    lp.addConstraint(new LinearBiggerThanEqualsConstraint(curCons, 0, "a" + j));
  }
  lp.setMinProblem(true);
  LinearProgramSolver solver = SolverFactory.newDefault();
  return solver.solve(lp);

}

void update() {

  currentTime += 1;
  if (currentTime >= 1440) {
    cycle += 1;
    currentTime = 0;
  }

  double[][] curS = arrival_rate[currentTime];
  //curS = arrival_rate[0];
  for (int i = 0; i < hub.trips.size(); i++) {
    hub.trips.get(i).update();
    if(hub.trips.get(i).des <= 0) {
      hub.viecles[hub.trips.get(i).i][hub.trips.get(i).j] -= 1;
      hub.viecles[hub.trips.get(i).j][hub.trips.get(i).j] += 1;
      hub.trips.remove(i);
      i = i-1;
    }
  }
  for (int i = 0; i < total_hub; i++) {
    for(Consumer a : hub.waitings[i]) {
      a.update();
    }
    for (int j = 0; j < hub.waitings[i].size(); j++) {
      if (hub.waitings[i].get(j).waitTime <= 0) {
        hub.waitings[i].remove(j);
        clost += 1;
        lostC[i] += 1;
        j = j-1;
      }
    }
    for (int j = 0; j < total_hub; j++) {
      if (random(0,1) < curS[i][j]) {
        hub.waitings[i].add(new Consumer(i, j));
      }
    }
    while(hub.viecles[i][i] > 0 && hub.waitings[i].size() > 0) {
      ttotal += 1;
      hub.trips.add(new Trip(i, hub.waitings[i].get(0).j));
      hub.waitings[i].remove(0);
      hub.viecles[i][i] -= 1;
    }
  }
  
  if (currentTime % 60 == 0) {
    double[] k = lp();
    println(Arrays.toString(k));
    
    for (int i = 0; i < total_hub; i++) {
      hub.tasks[i].clear();
      for (int j = 0; j < total_hub; j++) {
        while (k[i*total_hub + j] > 0) {
          hub.tasks[i].add(new Task(i, j));
          k[i*total_hub + j] -= 1;
        }
      }
    
    }
  }
  
  for(int i = 0; i < total_hub; i++ ) {
    while(hub.viecles[i][i] > 0 && hub.tasks[i].size() > 0) {
      Trip atrip = new Trip(i, hub.tasks[i].get(0).j);
      atrip.task = true;
      hub.trips.add(atrip);
      hub.tasks[i].remove(0);
      hub.viecles[i][i] -= 1;
    }
  }

}

double distance(PVector a, PVector b) {
  return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
}

class Consumer {
  int waitTime;
  int i;
  int j;

  Consumer(int i, int j) {
    this.i = i;
    this.j = j;
    this.waitTime = (int)random(6, 25);
  }
  
  void update() {
    this.waitTime -= 1;
  }
}

class Task {
  int i;
  int j;

  Task(int i, int j) {
    this.i = i;
    this.j = j;
  }

}


class Trip {
  int i;
  int j;
  PVector cur;
  float xvie_speed;
  float yvie_speed;
  double des;
  boolean task = false;
  
  Trip(int i, int j) {
    this.i = i;
    this.j = j;
    this.cur = new PVector(hub.locations[i].x, hub.locations[i].y);
    float angle = atan2(hub.locations[j].y - hub.locations[i].y, hub.locations[j].x - hub.locations[i].x);
    this.xvie_speed = (float)cos(angle)*(float)vie_speed;
    this.yvie_speed = (float)sin(angle)*(float)vie_speed;
    this.des = hub.dis[i][j];
  }

  void update() {
    cur.x += xvie_speed ;
    cur.y += yvie_speed ;
    des -= vie_speed ;
  }

  void render() {
    if (task == true) {
      strokeWeight(5);
      fill(60, 160);
      stroke(180, 160);
      line(hub.locations[this.i].x, hub.locations[this.i].y, hub.locations[this.j].x, hub.locations[this.j].y);
      strokeWeight(1);
      fill(0,0,255, 200);
    }
    else {
      fill(20,200);
    }
    ellipse(cur.x, cur.y, 10, 10);
  }
}

class HubC {
  PVector[] locations;
  ArrayList<Consumer>[] waitings;
  double[][] dis;
  int [][] viecles;
  int [] line;
  ArrayList<Trip> trips = new ArrayList<Trip>();
  ArrayList<Task>[] tasks;
  
  HubC(int total_hub, int total_vie) {
    this.locations = new PVector[total_hub];
    this.line = new int[total_hub];
    this.waitings = (ArrayList<Consumer>[])new ArrayList[total_hub];
    this.tasks = (ArrayList<Task>[]) new ArrayList[total_hub];


    for (int i = 0; i < total_hub; i++) {
      this.locations[i] = new PVector(random(0,800), random(0,800));
      this.line[i] = 0;
      this.waitings[i] = new ArrayList<Consumer>();
      this.tasks[i] = new ArrayList<Task>();
    }
    this.viecles = new int[total_hub][total_hub];
    int c = total_vie;
    this.dis = new double[total_hub][total_hub];
    for (int i = 0; i < total_hub; i++) {
      for (int j = 0; j < total_hub; j++) {
        this.dis[i][j] = distance(locations[i], locations[j]);
        if (i == j) {
          this.viecles[i][j] = (int)total_vie / total_hub;
          c -= (int)total_vie / total_hub;
        }
        else {
          this.viecles[i][j] = 0;
        }
      }
    }
    this.viecles[total_hub-1][total_hub-1] = c+(int)total_vie/total_hub;

  }


}

void keyPressed() {
  if (key == 'n') {
    setup();
  }

}
