//THIS Code Can be used to create multi-Layered fabrics with pockets between the layers:
//it generates a structure map that walks through two images (pockets and tunnels) and swaps the top two or bottom two warp systems accordingly
//specifically, a pocket swaps the yarns on layers 1 and 2, a tunnels swaps between 2,3
//after the structure map is created - it represets the layer position of each yarn as a black square
//next the "texture" layer is applied to assign a stitch pattern to the associated layers. 

import java.util.*;

public static final int  LAYERS = 3;
public static final int  SOURCE_ROWS = 1320;
public static final int  WARPS = 1320;


int map_height = LAYERS*SOURCE_ROWS;

PImage pockets;
PImage tunnels;
PImage texture;
PImage openings;

/*A BitSet (Yarn-Layer Map) that maps yarn indexes to their corresponding layers a true represents a place where that yarn sits on the corresponding layer. 
this is NOT a draft, it is a "graph" that has yarn ids on rows, and layer IDs repeating in column. Each pixel in the uploaded images will correspond to a 3x3 
block of info in the bitset. 
*/

BitSet yl_map;

// this is the final output and exists in weavable form
BitSet draft;

//create some stitches to start
BitSet twill;
BitSet i_twill;

void setup() {

  size (1320, 1320); 

  pockets = loadImage("pockets.png"); //pockets between layers 1&2
  tunnels = loadImage("tunnels.png"); //pockets between 2&3
  texture = loadImage("texture.png"); //the textured patterns to be applied to each layer
  openings = loadImage("openings.png"); //integrated openings
  
  //create 3/1 twills
  twill = new BitSet(9*LAYERS*LAYERS);
  i_twill = new BitSet(9*LAYERS*LAYERS);
  
  for(int ndx = 0; ndx < (9*LAYERS*LAYERS); ndx++){
      int i = ndx / (3*LAYERS);
      int j = ndx % (3*LAYERS);
      if((i/3) == (j/3)) twill.set(ndx);
      if((j/3) != (2-(i/3))) i_twill.set(ndx);
  }
  
  printTextMap(twill);
  println();
  printTextMap(i_twill);

  
 
  //a weaveable file that includes the stitch patterns on top of the structure. 
  draft = new BitSet (map_height*WARPS);

  yl_map = createYarnLayerMap(); 
  
  draft = yl_map.get(0, yl_map.size());
  draft = addTexture(draft, yl_map, twill, i_twill);
  draft = makeDraft(draft, yl_map);  
  draft = addOpenings(draft, yl_map);
   
  println("DRAFT NUM ROWS: "+draft.size()/1320);
  printMap(draft);
}


void loop() {
}

BitSet createYarnLayerMap() {
  
  yl_map = new BitSet(map_height*WARPS);
  
  
  println("INIT: "+map_height*WARPS);
  println("SIZE: "+yl_map.size());
  
  boolean p1_val = false;
  boolean p2_val = false;
  boolean p1_last = false;
  boolean p2_last = false;

  //store currnt layer ordering
  //layer 1 = yarn 1, layer 2 = yarn 2, ...
  int ys[];
  ys = new int[3];
  ys[0] = 0; 
  ys[1] = 1; 
  ys[2] = 2;


  pockets.loadPixels();
  tunnels.loadPixels();
  
  println(pockets.pixels.length);

  for(int ndx = 0; ndx < pockets.pixels.length; ndx++){
    int i = ndx / WARPS;
    int j = ndx % WARPS;
    
    color p1 = pockets.pixels[ndx];
    color p2 = tunnels.pixels[ndx];

    
    //if this is the first in the row, reset the yarn order based on combination of pixels
    if(j % WARPS == 0){
      
      
      
      if(red(p1) < 255 && red(p2) < 255){
          //youre on a tunnel and a pocket 
          ys[0] = 2; 
          ys[1] = 0; 
          ys[2] = 1;
          
          p1_last = true;
          p2_last = true;
      }else if(red(p1) < 255 && red(p2) == 255){
          //youre on a pocket
          ys[0] = 1; 
          ys[1] = 0; 
          ys[2] = 2;
          p1_last = true;
          p2_last = false;
      }else if(red(p1) == 255 && red(p2) < 255){
          //youre on a tunnel
          ys[0] = 0; 
          ys[1] = 2; 
          ys[2] = 1;
          p1_last = false;
          p2_last = true;
      }else{
          ys[0] = 0; 
          ys[1] = 1; 
          ys[2] = 2;
          p1_last = false;
          p2_last = false;
      }
      
    }
    
    //take a sample every LAYER Yarns on the x-axis, and make sure it doesn't overrun the width
    if((j% LAYERS == 0) && (WARPS - j > 2)){
    
       if (red(p1) < 255) p1_val = true;
       else p1_val = false;

       if (red(p2) < 255) p2_val = true;
       else p2_val = false;

       if (p1_last != p1_val) {
          int temp = ys[1]; 
          ys[1] = ys[0];
          ys[0] = temp;
        }

        if (p2_last != p2_val) {
          int temp = ys[1]; 
          ys[1] = ys[2];
          ys[2] = temp;
        }

        p1_last = p1_val;
        p2_last = p2_val;

        //write a 3x3 stitch to represent this stucture and add it into the BitSet at sx, sy
        int sx = j;
        int sy = i * LAYERS;
   
        for (int yi = 0; yi< LAYERS; yi++) {
     
          //get the layer corresponding to yarn yi
          int al = ys[yi];
  
          //walk to the three spaces to the right
          for (int yj = 0; yj < 3; yj++) {
            
            //put a "true" on the layer corresponding to this yarn
            int map_ndx = (sy+yi)*WARPS + (sx+yj);
            if (yj == al)  yl_map.set(map_ndx);
          }
        }
    }
  }
  
  return yl_map;
}


BitSet makeDraft(BitSet draft, BitSet map){
  
  BitSet fill = new BitSet(WARPS*map_height);
  
  for(int ndx = 0; ndx < draft.size(); ndx++){
    
    int i = ndx / WARPS;
    int j = ndx % WARPS;
    
    if(j % 3 == 0 && (WARPS - j) > 2){
    
      //find the first bit in the group of three and make the ones to the left blank for structure
      int layer = map.nextSetBit(i*WARPS+j);
      
      for(int k = ndx; k < layer; k++){
        fill.set(k);
      }
    }
    
  }
  
  draft.or(fill);  
  return draft;
}

BitSet addTexture(BitSet draft, BitSet map, BitSet t1, BitSet t2){  
  texture.loadPixels();
  
  BitSet t1_map = new BitSet(map.size());
  BitSet t2_map = new BitSet(map.size());
  BitSet texture_map = new BitSet(map.size());

 
 //create a map the size of the the original map that has the stitch pattern repeated
 for(int ndx = 0; ndx < map.size(); ndx++){
   int i = ndx / WARPS;
   int j = ndx % WARPS;
   
   int ndx_i = i % (3*LAYERS); //cycle through the row in the stitch 
   int ndx_j = j % (3*LAYERS); //cycle through the columns in the stitch
   
   t1_map.set(ndx, t1.get(ndx_i*(3*LAYERS)+ndx_j));
   t2_map.set(ndx, t2.get(ndx_i*(3*LAYERS)+ndx_j));
 }
 
 
 //stretch this to same size as map
 for(int ndx = 0; ndx < texture.pixels.length; ndx++){
   int i = ndx / WARPS;
   int j = ndx % WARPS;
   
   color c = texture.pixels[ndx];
   int map_ndx = (i*LAYERS)*WARPS+j; 
   if(red(c) < 255){
     texture_map.set(map_ndx, true);
     texture_map.set(map_ndx+WARPS, true);
     texture_map.set(map_ndx+WARPS*2, true);
     
   }else{
     texture_map.set(map_ndx, false);
     texture_map.set(map_ndx+WARPS, false);
     texture_map.set(map_ndx+WARPS*2, false);  
   }
 }
 


  //create a bitset that has the stitches "filled" into the colored sections
 t1_map.and(texture_map);
 texture_map.flip(0, texture_map.size()); 
 t2_map.and(texture_map);

 //t1 map now has the entire map (of both t1 and t2 regions)
 t1_map.or(t2_map);
 
 
 //init the draft with the layer map
 draft = map.get(0, map.size());
 
 //AND the layer map to get the alternating layer stitches
 draft.and(t1_map);
 

 return draft;
 
}

void printTextMap(BitSet map) {
  
  for (int ndx = 0; ndx < map.size(); ndx++) {   
    int j = ndx % (3*LAYERS);
    if(j == 0) println();
    if (map.get(ndx)) {
        print("x ");
      } else {
        print("- ");
      }
    
  }
}

void printMap(BitSet map) {

  PImage mapImage = createImage(WARPS, map.size()/WARPS, RGB);
  mapImage.loadPixels();
  
  for(int ndx = 0; ndx < mapImage.pixels.length; ndx++){
    
    if (map.get(ndx)) {
        mapImage.pixels[ndx] = color(0);
    }else{
        mapImage.pixels[ndx] = color(255);
    }
    mapImage.updatePixels();
  }
  
  image(mapImage, 0, 0);
  mapImage.save("map.tif");
  
}


BitSet addOpenings(BitSet draft, BitSet map){

  ////add a fourth shuttle to the whole file (as a blank white line)

  BitSet ex_draft;
  
  int expanded_size = draft.size() / LAYERS * (1+LAYERS);
  ex_draft = new BitSet(expanded_size);
  println("len "+ex_draft.length()+" size "+ex_draft.size());
  println(expanded_size);
  
    
  for(int ndx = 0; ndx < draft.size(); ndx++){
    int i = ndx / WARPS;
    int j = ndx % WARPS;
    
    int ex_i = i/LAYERS + i; 
     ex_draft.set(ex_i*WARPS+j, draft.get(i*WARPS+j));
  }
  
    
  openings.loadPixels();
  for(int ndx = 0; ndx < openings.pixels.length; ndx++){
    color c = openings.pixels[ndx];
    
    //of you have hit the opening, then...
    if(red(c) < 255){
     
      
      int i = ndx / WARPS;
      int j = ndx % WARPS;
      
      //increment j down to the nearest multiple of LAYERS
      j = j - (j%LAYERS);
     // println(j);
      
      //map from image to map
      int map_row_id = (i*LAYERS);
     // println("map row ID "+i+"-->"+map_row_id+"-->"+i*(LAYERS+1));
      
      //figure out which yarn is on layer 1
      int select_yarn = -1;
      boolean found = false;
      
      //iterate down 3 rows to check
      //k should iterate down the first row of a 3x3 block,if the first block = true, then its on layer 1
      for(int k = map_row_id; k < map_row_id+LAYERS && !found; k++){
        if(map.get(k*WARPS+j)){
          select_yarn = k;
          found = true;
        }
      }
      
      //println("selected yarn is "+select_yarn%LAYERS);
    
      
      //we now need to map from yl_map (which is a multiple of layes) to ex_draft (which is a multiple of Layers+1)
      int ex_draft_i = ((select_yarn/LAYERS) * (LAYERS+1)) + select_yarn%LAYERS;
      int ex_draft_blank = ((select_yarn/LAYERS) * (LAYERS+1)) + LAYERS;
      
      //Mmove the draft from the right of the slit to the new row
      for(int ex_ndx = 0; ex_ndx < WARPS; ex_ndx++){
        if(ex_ndx >= j){
          //copy the cell to the blank row
          ex_draft.set(ex_draft_blank*WARPS+ex_ndx, ex_draft.get(ex_draft_i*WARPS+ex_ndx));
          ex_draft.set(ex_draft_i*WARPS+ex_ndx, false);
        }
      }
      
      
    
    }
   
  }
  

  
  return ex_draft;
  
}