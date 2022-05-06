
class Entity {
  num id;
  num size;
  int speed;
  double damage_value;
  double health;
  String name;
  World world;
  Vector2 location;
  StateMachine brain;
  Vector2 destination;
  bool remove = false;

  Entity(String name) {
    this.name = name;
    this.brain = new StateMachine();
  }

  void render(CanvasRenderingContext2D context) {

  }

  void process(double gameTime) {
    this.brain.think();
  }
}
