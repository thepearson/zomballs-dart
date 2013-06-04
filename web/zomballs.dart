import 'dart:html';
import 'dart:math' as Math;
import 'package:vector_math/vector_math.dart';
import 'package:game_loop/game_loop_html.dart';
import 'package:asset_pack/asset_pack.dart';

num LOG_DEBUG = 3;
num LOG_INFO = 2;
num LOG_ERROR = 1;

var game_size = [800, 600];
var game_flip_sights = false;
var game_stats_update_interval = 1.0;
var game_score_update_interval = 0.5;
var game_increase_zomball_interval = 5.0;
var game_increase_zomball_number = 2.0;

var player_default_health = 100.0;
var player_size = 50;

var zomball_spawn_offset = 250;
var zomball_max_count = 10;
var zomball_alert_range = 100;
var zomball_walking_change_offset = 400;
var zomball_change_direction_possibility = 10;
var zomball_alert_charge_possibility = 50;
var zomball_charge_speed = 50;
var zomball_speed_min = 50;
var zomball_speed_range = 15;
var zomball_size = 20;
var zomball_death_time = 3;
var zomball_charge_possibility = 10;
var zomball_eating_grass_possibility = 20;
var zomball_dest_reach_move_possibility = 5;
var zomball_spawn_new_zomball_delay = 0.2;
var zomball_spawn_restrained = true;
var zomball_default_health = 100.0;
var zomball_damage_value = 5.0;

num debug_level = 0;


/**
 * Helper function to output debug messages
 */
void dbg(String message, [num level = 3]) {
  if (debug_level >= level) {
    print(message);
  }
}


/**
 * Specify color
 */
class Color {
  num r, g, b;
  double a;
  Color(num r, num g, num b, [num a]) {
    this.r = r;
    this.g = g;
    this.b = b;
    if (?a) {
      this.a = a;
    } else {
      this.a = 1.0;
    }
  }

  List get_rgb() {
    return [this.r, this.g, this.b];
  }

  List get_hsl() {
    final max = Math.max(Math.max(r, g), b);
    final min = Math.min(Math.min(r, g), b);
    final d = max - min;

    double h;
    if (max == min) {
      h = 0.0;
    } else if (max == r) {
      h = 60 * (g-b)/d;
    } else if (max == g) {
      h = 60 * (b-r)/d + 120;
    } else { // max == b
      h = 60 * (r - g)/d + 240;
    }

    final l = (max + min)/2;

    double s;
    if (max == min) {
      s = 0.0;
    } else if (l < 0.5) {
      s = d/(2*l);
    } else {
      s = d/(2 - 2*l);
    }

    return [(h.round() % 360).toInt(), s, l];
  }

  String get_hex() {
    return '#${_hexPair(r/255)}${_hexPair(g/255)}${_hexPair(b/255)}';
  }

  String _hexPair(double color) {
    assert(color >= 0 && color <= 1);
    final str = (color * 0xff).round().toRadixString(16);
    return str.length == 1 ? '0$str' : str;
  }
}


/**
 * Interface for defining states for game entities
 * a state could be walking, running, shooting etc.
 * All states, should implement the following methods.
 */
class State {
  String name;
  void do_actions() {}
  String check_conditions() {
    return null;
  }
  void entry_actions() {}
  void exit_actions() {}
}



class World {
  Map<num,Entity> entities;
  Player player;
  num player_score = 0;
  num entity_id = 0;
  Vector2 target;
  Bullet bullet;
  Color target_color;

  World() {
    this.entities = new Map();
    this.target_color = new Color(255, 128, 128);
  }

  Entity get_entity(num id) {
    return this.entities[id];
  }

  void add_entity(Entity entity) {
    entity.id = entity_id;
    entity.world = this;
    this.entities[entity_id] = entity;
    this.entity_id += 1;
  }

  void add_player(Entity entity) {
    entity.id = 999999;
    entity.world = this;
    this.player = entity;
  }

  void unset_target() {
    this.target = null;
  }

  void set_target_position(Vector2 mouse_pos) {
    //  this.zomball.destination = ((this.zomball.destination-this.zomball.location)*-1.0)+this.zomball.location;
    if (game_flip_sights == true) {
      this.target = (((mouse_pos-this.player.location)*1.5)*-1.0)+this.player.location;
    } else {
      this.target = mouse_pos;
    }
  }

  void fire_bullet() {
    this.bullet = new Bullet(this.player.location, this.target);
    this.bullet.world = this;
    this.target = null;
  }

  void draw_target(context) {
    if (this.target != null) {
      context.beginPath();
      context.lineWidth = 1;
      context.strokeStyle = this.target_color.get_hex();
      context.moveTo(this.player.location.x, this.player.location.y);
      context.lineTo(this.target.x, this.target.y);

      //context.arc(this.target.x, this.target.y, 2, 0, 2 * Math.PI, false);
      //context.lineWidth = 2;
      //context.strokeStyle = "red";
      context.stroke();
    }
  }

  num count_entities(String type) {
    num count = 0;
    for (num id in this.entities.keys) {
      if (?type) {
        if (this.entities[id].name == type && this.entities[id].remove == false) {
          count++;
        }
      } else {
        count++;
      }
    }
    dbg("Current entity count ${type}: ${count}.", LOG_DEBUG);
    return count;
  }

  void remove_entity(num id) {
    this.entities.remove(id);
    dbg("Entity ${id} removed.", LOG_DEBUG);
  }

  void render(canvas) {
    CanvasRenderingContext2D context = canvas.getContext("2d");
    context.clearRect(0, 0, canvas.width, canvas.height);

    for (num id in this.entities.keys) {
      this.entities[id].render(canvas);
    }
    // draw target if any
    this.draw_target(context);
    this.player.render(canvas);

    if (this.bullet != null) {
      this.bullet.render(canvas);
    }
  }

  bool out_of_range(Vector2 location) {
    num x = location.x;
    num y = location.y;
    if (x < (0-zomball_spawn_offset) || x > (game_size[0]+zomball_spawn_offset)) {
      return true;
    }
    if (y < (0-zomball_spawn_offset) || y > (game_size[1]+zomball_spawn_offset)) {
      return true;
    }
    return false;
  }

  void remove_entities() {
    List<num> ids = [];
    for (num id in this.entities.keys) {
      if (this.entities[id].remove == true) {
        ids.add(id);
      }
    }
    for (num id in ids) {
      this.entities.remove(id);
    }
  }

  void process(double gameTime) {
    this.remove_entities();
    for (num id in this.entities.keys) {
      this.entities[id].process(gameTime);
    }
    this.player.process(gameTime);
    if (this.bullet != null) {
      if (this.bullet.remove == true) {
        this.bullet = null;
      } else {
        this.bullet.process(gameTime);
      }
    }
  }

  bool within_range(Vector2 vector1, Vector2 vector2, num range) {
    Vector2 distance_vector = vector1-vector2;
    if (distance_vector.length <= range) {
      return true;
    }
    return false;
  }

  List get_entities_in_range(Entity entity, num range) {
    List entities = [];
    for (num id in this.entities.keys) {
      if (entity.id != id) {
        if (this.within_range(entity.location, this.entities[id].location, range)) {
          entities.add(id);
        }
      }
    }
    return entities;
  }

  Entity get_close_entity(Entity entity, num range) {
    for (num id in this.entities.keys) {
      //if (this.entities[id].name == entity.name) {
        // we only care if it isn't the current entity
      if (entity.id != id) {
        if (this.within_range(entity.location, this.entities[id].location, range)) {
          return this.entities[id];
        }
      }
      //}
    }
    return null;
  }
}


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

  void render(CanvasElement canvas) {

  }

  void process(double gameTime) {
    this.brain.think();
  }
}



class ZomballStateWalking extends State {

  Zomball zomball;

  ZomballStateWalking(Zomball zomball) {
    this.name = "walking";
    this.zomball = zomball;
  }

  void choose_destination({bool mirror: false}) {
    var rand = new Math.Random();
    // destination not set, so lets choose one
    // somewhere on the game field
    if (this.zomball.destination == null) {
      this.zomball.destination = new Vector2(
        rand.nextInt(game_size[0]).toDouble(),
        rand.nextInt(game_size[0]).toDouble()
      );
    } else {
      // destination is set so lets choose one close
      // to where the current one is. so we dont get crazy jerky
      // movements

      // if zomball has reached their destination then chose a completely
      // new one, but only after
      if (this.zomball.destination == this.zomball.location) {
        if (rand.nextInt(zomball_dest_reach_move_possibility) == 0) {
          this.zomball.destination = new Vector2(
            rand.nextInt(game_size[0]).toDouble(),
            rand.nextInt(game_size[0]).toDouble()
          );
        }
      }
      else {
        // set some defaults for the new locations
        int new_x, new_y = 0;

        // first work out x
        int x_offset = rand.nextInt(zomball_walking_change_offset);
        if (rand.nextInt(1) == 1) {
          // positive
          new_x = (this.zomball.destination.x+x_offset).round();
        } else {
          // negative
          new_x = (this.zomball.destination.x+x_offset).round();
        }

        // first work out x
        int y_offset = rand.nextInt(zomball_walking_change_offset);
        if (rand.nextInt(1) == 1) {
          // positive
          new_y = (this.zomball.destination.y+y_offset).round();
        } else {
          // negative
          new_y = (this.zomball.destination.y+y_offset).round();
        }

        // set the new destination
        this.zomball.destination = new Vector2(
          new_x.toDouble(),
          new_y.toDouble()
        );
      }
    }
  }

  void do_actions() {
    var rand = new Math.Random();

    if (this.zomball.world.out_of_range(this.zomball.destination) &&
      this.zomball.world.out_of_range(this.zomball.location)) {
      this.zomball.remove = true;
    }

    if (this.zomball.world.get_close_entity(this.zomball, this.zomball.size) != null) {
      // reverse the destination
      this.zomball.destination = ((this.zomball.destination-this.zomball.location)*-1.0)+this.zomball.location;
    }

    // only update the direction of the zomball one in every
    // zomball_walking_change_offset ticks, but randomly
    if (rand.nextInt(zomball_walking_change_offset) == 0) {
      this.choose_destination();
    }
  }

  String check_conditions() {
    if (this.zomball.health <= 0) {
      return "dead";
    }
    var rand = new Math.Random();
    if (this.zomball.world.within_range(this.zomball.location, this.zomball.world.player.location, zomball_spawn_offset)) {
      if (rand.nextInt(zomball_charge_possibility) == 0) {
        return "charging";
      }
    }
    return null;
  }

  void entry_actions() {
    this.choose_destination();
  }
}


class ZomballStateAlerted extends State {

  Zomball zomball;

  ZomballStateAlerted(Zomball zomball) {
    this.name = "alerted";
    this.zomball = zomball;
  }

  void entry_actions() {
    // increase speed
    this.zomball.speed = 0;

    // set destination as the player
    this.zomball.destination = this.zomball.world.player.location;
  }

  String check_conditions() {
    if (this.zomball.health <= 0) {
      return "dead";
    }

    var rand = new Math.Random();
    if (rand.nextInt(zomball_alert_charge_possibility) == 0) {
      return "charging";
    }
    return null;
  }
}



class ZomballStateCharging extends State {

  Zomball zomball;

  ZomballStateCharging(Zomball zomball) {
    this.name = "charging";
    this.zomball = zomball;
  }

  void entry_actions() {
    // increase speed
    this.zomball.speed = zomball_charge_speed;

    // set destination as the player
    this.zomball.destination = this.zomball.world.player.location;
  }

  String check_conditions() {
    if (this.zomball.health <= 0) {
      return "dead";
    }
  }
}

class ZomballStateEatingGrass extends State {

  Zomball zomball;

  ZomballStateEatingGrass(Zomball zomball) {
    this.name = "eating_grass";
    this.zomball = zomball;
  }

  void entry_actions() {
    // increase speed
    this.zomball.speed = 0;

    // set destination as the player
    this.zomball.destination = this.zomball.location;
  }

  String check_conditions() {
    if (this.zomball.health <= 0) {
      return "dead";
    }

    var rand = new Math.Random();
    // if the zomball decides to move
    if (rand.nextInt(zomball_dest_reach_move_possibility) == 0) {

      // it might charge or walk.
      if (this.zomball.world.within_range(this.zomball.location, this.zomball.world.player.location, zomball_spawn_offset)) {
        if (rand.nextInt(zomball_charge_possibility) == 0) {
          return "charging";
        }
      }
      return "walking";
    }
  }
}


class ZomballStateDead extends State {

  Zomball zomball;
  Color dead_color;
  int entry_time;

  ZomballStateDead(Zomball zomball) {
    this.name = "dead";
    this.zomball = zomball;
    this.dead_color = new Color(128, 90, 0); //brown
  }

  void entry_actions() {
    // increase speed
    this.zomball.speed = 0;
    this.entry_time = new DateTime.now().millisecondsSinceEpoch;
    this.zomball.color = this.dead_color;

    // set destination as the player
    this.zomball.destination = this.zomball.world.player.location;
  }

  void do_actions() {
    int now = new DateTime.now().millisecondsSinceEpoch;
    if (((now-this.entry_time)/1000).round() > zomball_death_time) {
      this.zomball.remove = true;
    }
  }
}


/**
 * The state machine is the brain for a given entity.
 */
class StateMachine {

  // Map holds all possible states for the entity
  Map<String,State> states;

  // This is the name of the active state
  String active_state;

  /**
   * Construct
   */
  StateMachine() {
    this.states = new Map();
    this.active_state = null;
  }

  /**
   * Add a state to the state machine
   */
  void add_state(State state) {
    this.states[state.name] = state;
  }

  /**
   * this processes the actions for the current state
   * it will also check for any conditions on the existing
   * state that could change the state of the entity, thus
   * altering the state of the entity
   */
  void think() {
    if (this.active_state == null) {
      return;
    }
    this.states[this.active_state].do_actions();
    var new_state = this.states[this.active_state].check_conditions();
    if (new_state != null) {
      this.set_state(new_state);
    }
  }

  /**
   * Returns the active state
   */
  State get_active_state() {
    return this.states[this.active_state];
  }

  /**
   * Sets the active state, runs any exit actions for the old active
   *  state (if any) and runs entry actions for the new state.
   */
  void set_state(String state_name) {
    if (this.active_state != null) {
      this.states[this.active_state].exit_actions();
    }
    this.active_state = this.states[state_name].name;
    this.states[this.active_state].entry_actions();
  }

}


class Bullet extends Entity {
  Color color;

  Bullet(Vector2 location, Vector2 destination) : super("bullet") {
    var rand = new Math.Random();
    this.location = location;
    this.destination = destination;
    this.size = 2;
    this.damage_value = 75.0;
    this.color = new Color(0, 0, 0);
    this.speed = 1000;
  }

  /**
   * Render the zomball
   */
  void render(CanvasElement canvas) {
    super.render(canvas);
    CanvasRenderingContext2D context = canvas.getContext("2d");
    context.beginPath();
    context.arc(this.location.x, this.location.y, (this.size/2).round(), 0, 2 * Math.PI, false);
    context.fillStyle = this.color.get_hex();
    context.fill();
    context.stroke();
  }

  /**
   * Process the zomballs movements and actions
   */
  void process(double gameTime) {
    super.process(gameTime);

    Entity zomball = this.world.get_close_entity(this, zomball_size);
    if (zomball != null) {
      // decrease zomball health
      zomball.health -= this.damage_value;
      this.world.player_score += this.damage_value;

      // set for removal
      this.remove = true;

      // lets set others in range to alert, but only of they aren't charging
      List in_range = this.world.get_entities_in_range(zomball, zomball_alert_range);
      for (var id in in_range) {
        if (this.world.entities[id].brain.active_state != "charging") {
          this.world.entities[id].brain.set_state("alerted");
        }
      }
    }

    // remove the bullet when it reaches it's destination.
    if (this.world.within_range(this.location, this.destination, 10)) {
      this.remove = true;
    }

    // if we are moving towards the destination
    if (this.speed > 0 && this.location != this.destination) {
      Vector2 vec_to_destination = this.destination - this.location;
      double distance_to_destination = vec_to_destination.length;
      Vector2 heading = vec_to_destination.normalized();
      num distance_traveled = Math.min(distance_to_destination, gameTime * this.speed);
      Vector2 travel_vector = heading * distance_traveled;

      // new location is the current location
      // plus the distance traveled vector
      this.location = this.location + travel_vector;
    }
  }
}


class Zomball extends Entity {
  Color color;
  bool in_sights = false;
  Color in_sights_color = new Color(255, 128, 0);

  Zomball() : super("zomball") {
    var rand = new Math.Random();
    this.size = zomball_size;
    this.health = zomball_default_health;
    this.set_spawn();
    this.damage_value = zomball_damage_value;
    this.color = new Color(0, 128, 0);
    this.brain.add_state(new ZomballStateWalking(this));
    this.brain.add_state(new ZomballStateCharging(this));
    this.brain.add_state(new ZomballStateEatingGrass(this));
    this.brain.add_state(new ZomballStateAlerted(this));
    this.brain.add_state(new ZomballStateDead(this));
    this.brain.set_state("walking");
    this.speed = zomball_speed_min+rand.nextInt(zomball_speed_range);
  }


  /**
   * Render the zomball
   */
  void render(CanvasElement canvas) {
    super.render(canvas);
    CanvasRenderingContext2D context = canvas.getContext("2d");
    context.beginPath();
    context.arc(this.location.x, this.location.y, (this.size/2).round(), 0, 2 * Math.PI, false);
    if (this.in_sights) {
      context.fillStyle = in_sights_color.get_hex();
    } else {
      context.fillStyle = this.color.get_hex();
    }
    context.fill();
    context.lineWidth = 1;
    context.strokeStyle = this.color.get_hex();
    context.stroke();

    var health_bar_length = 20;
    var health_bar_width = 3;
    var health_bar_empty_color = 'red';
    var health_bar_full_color = 'green';

    var line_x = (this.location.x-(this.size/2)).round();
    var line_y = (this.location.y-((this.size/2)+health_bar_width)).round();

    // if player health is less than default health
    if (this.health < player_default_health) {
      context.beginPath();
      context.lineWidth = health_bar_width;
      context.strokeStyle = health_bar_empty_color;
      context.moveTo(line_x, line_y);
      context.lineTo(line_x+health_bar_length, line_y);
      context.stroke();

      health_bar_length = ((this.health/100)*health_bar_length).round();
    }

    if (this.health > 0) {
      context.beginPath();
      context.lineWidth = health_bar_width;
      context.strokeStyle = health_bar_full_color;
      context.moveTo(line_x, line_y);
      context.lineTo(line_x+health_bar_length, line_y);
      context.stroke();
    }
  }

  /**
   * Process the zomballs movements and actions
   */
  void process(double gameTime) {
    super.process(gameTime);

    if (this.world.within_range(this.location, this.world.player.location, (this.world.player.size/2)+( this.size/2))) {
      this.world.player.take_damage(this.damage_value);
      this.remove = true;
    }

    // if we are moving towards the destination
    if (this.speed > 0 && this.location != this.destination) {
      Vector2 vec_to_destination = this.destination - this.location;
      double distance_to_destination = vec_to_destination.length;
      Vector2 heading = vec_to_destination.normalized();
      num distance_traveled = Math.min(distance_to_destination, gameTime * this.speed);
      Vector2 travel_vector = heading * distance_traveled;

      // new location is the current location
      // plus the distance traveled vector
      this.location = this.location + travel_vector;
    }
  }

  /**
   * This sets the initial spawn location of a zomball
   */
  void set_spawn() {
    var rand = new Math.Random();
    int x, y = 0;

    // whether r not to restrain the zomball with
    // zomball_spawn_offset from the center, ie a zomball
    // wont spawn within zomball_spawn_offset pixels in any directioon
    // of the center
    int spawn_direction = 4;
    if (zomball_spawn_restrained == true) {
      spawn_direction = rand.nextInt(4);
    }

    switch (spawn_direction) {
      case 0: // north
        x = rand.nextInt(game_size[0]);
        y = rand.nextInt((game_size[1]/2).round())-zomball_spawn_offset;
        break;
      case 1: // east
        x = (rand.nextInt((game_size[0]/2).round())+(game_size[0]/2).round()+zomball_spawn_offset);
        y = rand.nextInt(game_size[1]);
        break;
      case 2: // south
        x = rand.nextInt(game_size[0]);
        y = rand.nextInt((game_size[1]/2).round())+(game_size[1]/2).round()+zomball_spawn_offset;
        break;
      case 3: // west
        x = rand.nextInt((game_size[0]/2).round())-zomball_spawn_offset;
        y = rand.nextInt(game_size[1]);
        break;
      case 4:
        x = rand.nextInt(game_size[0]);
        y = rand.nextInt(game_size[1]);
        break;
    }
    this.location = new Vector2(x.toDouble(), y.toDouble());
  }
}


class Player extends Entity {

  Color color;

  Player() : super("player") {
    this.location = new Vector2((game_size[0]/2), (game_size[1]/2));
    this.size = player_size;
    this.health = player_default_health;
    this.color = new Color(128, 128, 255);
  }

  void take_damage(num value) {
    this.health -= value;
  }

  /**
   * Render the zomball
   */
  void render(CanvasElement canvas) {
    super.render(canvas);
    CanvasRenderingContext2D context = canvas.getContext("2d");
    context.beginPath();
    context.arc(this.location.x, this.location.y, (this.size/2).round(), 0, 2 * Math.PI, false);
    context.fillStyle = this.color.get_hex();
    context.fill();
    context.lineWidth = 1;
    context.strokeStyle = this.color.get_hex();
    context.stroke();

    var health_bar_length = 50;
    var health_bar_width = 5;
    var health_bar_empty_color = 'red';
    var health_bar_full_color = 'green';

    var line_x = (this.location.x-(this.size/2)).round();
    var line_y = (this.location.y-((this.size/2)+health_bar_width)).round();

    // if player health is less than default health
    if (this.health < player_default_health) {
      context.beginPath();
      context.lineWidth = health_bar_width;
      context.strokeStyle = health_bar_empty_color;
      context.moveTo(line_x, line_y);
      context.lineTo(line_x+health_bar_length, line_y);
      context.stroke();

      health_bar_length = ((this.health/100)*health_bar_length).round();
    }

    if (this.health > 0) {
      context.beginPath();
      context.lineWidth = health_bar_width;
      context.strokeStyle = health_bar_full_color;
      context.moveTo(line_x, line_y);
      context.lineTo(line_x+health_bar_length, line_y);
      context.stroke();
    }
  }

  /**
   * Process the zomballs movements and actions
   */
  void process(double gameTime) {
    super.process(gameTime);
  }
}



void main() {
  /**
   * Create a canvas element and place it in the
   * dom, as a child of #parent
   */
  var targeting = false;
  var time_elapsed = 0;
  var zomball_count = 0;
  var parent = query("#parent");
  var canvas = new Element.html('<canvas/>');
  canvas.width = game_size[0];
  canvas.height = game_size[1];
  parent.append(canvas);

  /**
   * Create a new game
   */
  World game = new World();
  game.add_player(new Player());

  GameLoopHtml gameLoop = new GameLoopHtml(canvas);
  gameLoop.pointerLock.lockOnClick = false;
  //gameLoop.enableFullscreen(true);


  gameLoop.onTouchStart = ((gameLoop, touch) {
    var positions = (touch as GameLoopTouch).positions;
  });

  /**
   * This runs game updates
   */
  gameLoop.onUpdate = ((gameLoop) {
    time_elapsed = gameLoop.gameTime.round();
    Mouse mouse = (gameLoop as GameLoopHtml).mouse;

    // if mouse button is pressed down on the player base
    if (mouse.pressed(Mouse.LEFT)) { //&& (game.within_range(
        //game.player.location,
        //new Vector2(mouse.x.toDouble(), mouse.y.toDouble()),
        //(game.player.size/2).round()))) {
      targeting = true;
    }

    if (mouse.isDown(Mouse.LEFT) && targeting == true) {
      game.set_target_position(new Vector2(mouse.x.toDouble(), mouse.y.toDouble()));
    }

    if (mouse.released(Mouse.LEFT) && targeting == true) {
      targeting = false;
      game.fire_bullet();
    }

    dbg("Begin update loop: Frame: ${gameLoop.frame}, Dt: ${gameLoop.dt}, GameTime: ${gameLoop.gameTime}", LOG_DEBUG);
    game.process(gameLoop.dt);
  });


  /**
   * This renders the game display
   */
  gameLoop.onRender = ((gameLoop) {
    dbg("Begin render loop: Interpolation factor: ${gameLoop.renderInterpolationFactor}", LOG_DEBUG);
    game.render(gameLoop.element);
  });

  gameLoop.start();


  /**
   * This timer will add new zomballs to the game, up to
   * zomball_max_count, a new zomball will spawn every
   * zomball_spawn_new_zomball_delay seconds
   */
  var timer = gameLoop.addTimer((timer) {
    if (game.count_entities("zomball") < zomball_max_count) {
      Zomball zomball = new Zomball();
      // only add the zomball if it isn't going to be inside another
      while (game.get_close_entity(zomball, zomball.size) != null) {
        dbg("Zomball ${zomball.id} position is being reset.", LOG_DEBUG);
        zomball.set_spawn();
      }

      dbg("Zomball ${zomball.id} has been added to the game.", LOG_DEBUG);
      game.add_entity(zomball);
    }
  }, zomball_spawn_new_zomball_delay, periodic:true);


  /**
   * Increase game difficulty
   */
  var increase_difficulty = gameLoop.addTimer((increase_difficulty) {
    zomball_max_count += game_increase_zomball_number;
  }, game_increase_zomball_interval, periodic:true);


  /**
   * Update stats
   */
  var stats_timer = gameLoop.addTimer((stats_timer) {
    query("#time").text = time_elapsed.toString();
    query("#count").text = game.count_entities("zomball").toString();
  }, game_stats_update_interval, periodic:true);

  /**
   * Update score
   */
  var score_timer = gameLoop.addTimer((score_timer) {
    query("#score").text = game.player_score.toString();
  }, game_score_update_interval, periodic:true);
}
