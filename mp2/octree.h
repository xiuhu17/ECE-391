
#ifndef OCTREE_H
#define OCTREE_H

#include "assert.h"
#include "modex.h"
#include "photo.h"
#include "photo_headers.h"
#include "world.h"
#include "octree.h"

#define QUERY_OFFSET 64
#define MASK_2_R    49152                       // 0b1100000000000000; >> 14; << 4  
#define MASK_2_G    1536                        // 0b0000011000000000>> 9; << 2 
#define MASK_2_B    24                          // 0b0000000000011000; >> 3; << 0 
#define MASK_4_R    61440                       // 0b1111000000000000; >> 12; << 8
#define MASK_4_G    1920                        // 0b0000011110000000; >> 7; << 4
#define MASK_4_B    30                          // 0b0000000000011110; >> 1; << 0   
#define CONVERT_R   3072                        // 0b110000000000; >> 10; << 4
#define CONVERT_G   192                         // 0b000011000000; >> 6; << 2
#define CONVERT_B   12                          // 0b000000001100; >> 2; << 0
#define RED         63488                       // 0b1111100000000000; >> 11 
#define GREEN       2016                        // 0b0000011111100000; >> 5
#define BLUE        31                          // 0b0000000000011111; >> 0 
#define SETRB       31                          // 0b11111; << 1
#define SETG        63                          // 0b111111; << 0
#define SIZE_FOUR   128                         // get first 128
#define SIZE_TWO    64    

#define ENTIRE_R    11
#define ENTIRE_G    5
#define ENTIRE_B    0

#define LEVEL_2_SIZE 64
#define LEVEL_4_SIZE 4096

typedef struct node{
    unsigned int count;                     //  the number of pixels in this node                
    unsigned int index;                     //  the index of current node
    unsigned int R;                         //  accumulate R
    unsigned int G;                         //  accumulate G
    unsigned int B;                         //  accumualte B
}node;

typedef struct octree{
    node LEVEL_2_Arr[LEVEL_2_SIZE];
    node LEVEL_4_Arr[LEVEL_4_SIZE]; 
    uint8_t tree_copy[192][3];
    int four_pix_to_idx[LEVEL_4_SIZE];         // unordered_map; use to map the four_level_to_final_idx
}octree;

/*Initialize the octree */
extern void octree_init(octree* tree);

/*Iterate all pixel, and put them in the tree */
extern void set_pixel(octree* tree, uint16_t pix);  

/*Use for quicksort*/
extern int cmpfunc (const void * f, const void * s);

/*Get 192 color we need, and put them into tree->tree_copy*/
extern void setup_photo(octree* tree);

/*Get the index of tree_copy or photo -> palette for each pixel */
extern unsigned int query_idx(octree* tree, uint16_t pix);

/* Get the index of pixel at LEVEL_2_Arr*/
extern unsigned int get_index_2(uint16_t value);

/* Get the index of pixel at LEVEL_4_Arr*/
extern unsigned int get_index_4(uint16_t value);

/* Travese to parent node index using level_4 index*/
extern unsigned int get_parent_index(unsigned int value);
#endif
