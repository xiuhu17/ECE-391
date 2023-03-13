#include "octree.h"
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/io.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
/* 
 *   octree_ini
 *   DESCRIPTION: Initialize an Octree
 * 
 *   INPUTS: Tree pointer
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: Set up and initialize the entire tree
 */
void octree_init(octree* tree) {
    unsigned int i;
    memset(tree -> four_pix_to_idx, -1, sizeof(tree -> four_pix_to_idx));
    for (i = 0; i < LEVEL_2_SIZE; i ++) {
        (tree -> LEVEL_2_Arr)[i].count = 0;
        (tree -> LEVEL_2_Arr)[i].index = i;
        (tree -> LEVEL_2_Arr)[i].R = 0;
        (tree -> LEVEL_2_Arr)[i].G = 0;
        (tree -> LEVEL_2_Arr)[i].B = 0;
    }
    for (i = 0; i < LEVEL_4_SIZE; i ++) {
        (tree -> LEVEL_4_Arr)[i].count = 0;
        (tree -> LEVEL_4_Arr)[i].index = i;
        (tree -> LEVEL_4_Arr)[i].R = 0;
        (tree -> LEVEL_4_Arr)[i].G = 0;
        (tree -> LEVEL_4_Arr)[i].B = 0;
    }
}

/* 
 *   set_pixel
 *   DESCRIPTION: Iterate all pixel, and put them in the tree
 * 
 *   INPUTS: Tree pointer tree, pixel used to setup
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: put all pixel in the tree at the propriate position
 */
void set_pixel(octree* tree, uint16_t pix) {
    unsigned int level_2_idx = get_index_2(pix);
    unsigned int level_4_idx = get_index_4(pix);
    unsigned int red = ((pix & RED) >> ENTIRE_R);
    unsigned int green = ((pix & GREEN) >> ENTIRE_G);
    unsigned int blue = ((pix & BLUE) >> ENTIRE_B);

    (tree -> LEVEL_2_Arr)[level_2_idx].count ++;
    (tree -> LEVEL_2_Arr)[level_2_idx].index = level_2_idx;
    (tree -> LEVEL_2_Arr)[level_2_idx].R += red;
    (tree -> LEVEL_2_Arr)[level_2_idx].G += green;
    (tree -> LEVEL_2_Arr)[level_2_idx].B += blue;

    (tree -> LEVEL_4_Arr)[level_4_idx].count ++;
    (tree -> LEVEL_4_Arr)[level_4_idx].index = level_4_idx;
    (tree -> LEVEL_4_Arr)[level_4_idx].R += red;
    (tree -> LEVEL_4_Arr)[level_4_idx].G += green;
    (tree -> LEVEL_4_Arr)[level_4_idx].B += blue;
}  

/* 
 *   cmpfunc
 *   DESCRIPTION: use to sort the LEVEL_4_Arr in decreasing sequence
 * 
 *   INPUTS: two void pointer
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: none
 */
int cmpfunc (const void * f, const void * s) {
    return (-((node*)f) -> count) + (((node*)s) -> count);
}

/* 
 *   set_pixel
 *   DESCRIPTION: Sort the level_4_array
 *                Get the most used 128 color in level 4 and 64 color in level 2
 *                Put them in corrosponding tree_copy, so we can put them to the palette 
 *                 
 *   INPUTS: Tree pointer tree
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: get the 192 color we needed, and set them into an array
 */
void setup_photo(octree* tree) {
    // first we should sort the LEVEL_4_Arr
    qsort(tree -> LEVEL_4_Arr, LEVEL_4_SIZE, sizeof(node), cmpfunc);
    
    // remove the RGB value in level 2 if it resides in PICK 4-level
    int i;
    for (i = 0; i < SIZE_FOUR; i ++) {
        unsigned int level_4_idx = (tree -> LEVEL_4_Arr)[i].index;
        unsigned int level_2_idx = get_parent_index(level_4_idx);
        (tree -> LEVEL_2_Arr)[level_2_idx].count -= (tree -> LEVEL_4_Arr)[i].count;
        (tree -> LEVEL_2_Arr)[level_2_idx].R -= (tree -> LEVEL_4_Arr)[i].R;
        (tree -> LEVEL_2_Arr)[level_2_idx].G -= (tree -> LEVEL_4_Arr)[i].G;
        (tree -> LEVEL_2_Arr)[level_2_idx].B -= (tree -> LEVEL_4_Arr)[i].B;
    }

    // get the avg value for LEVEL_2_Arr
    for (i = 0; i < SIZE_TWO; i ++) {
        unsigned int num = (tree -> LEVEL_2_Arr)[i].count;
        uint8_t red_avg, green_avg, blue_avg;
        if (num > 0) {
            red_avg = (tree -> LEVEL_2_Arr)[i].R / num;
            green_avg = (tree -> LEVEL_2_Arr)[i].G / num;
            blue_avg = (tree -> LEVEL_2_Arr)[i].B / num;
        } else {
            red_avg = 0;
            green_avg = 0;
            blue_avg = 0;
        }
        (tree -> tree_copy)[i][0] = ((red_avg & SETRB) << 1);
        (tree -> tree_copy)[i][1] = ((green_avg & SETG) << 0);
        (tree -> tree_copy)[i][2] = ((blue_avg & SETRB) << 1);
    }

    // get the avg value for LEVEL_4_Arr
    for (i = 0; i < SIZE_FOUR; i ++) {
        unsigned int level_4_idx = (tree -> LEVEL_4_Arr)[i].index;
        unsigned int num = (tree -> LEVEL_4_Arr)[i].count;
        uint8_t red_avg, green_avg, blue_avg;
        if (num > 0) {
            red_avg = (tree -> LEVEL_4_Arr)[i].R / num;
            green_avg = (tree -> LEVEL_4_Arr)[i].G / num;
            blue_avg = (tree -> LEVEL_4_Arr)[i].B / num;
        } else {
            red_avg = 0;
            green_avg = 0;
            blue_avg = 0;
        }
        (tree -> tree_copy)[i + SIZE_TWO][0] = ((red_avg & SETRB) << 1);
        (tree -> tree_copy)[i + SIZE_TWO][1] = ((green_avg & SETG) << 0);
        (tree -> tree_copy)[i + SIZE_TWO][2] = ((blue_avg & SETRB) << 1);
        (tree -> four_pix_to_idx)[level_4_idx] = i + SIZE_TWO;
    }

}

/* 
 *   set_pixel
 *   DESCRIPTION: Get the corrospndoing index in palette/tree_copy useing pixel
 *                 
 *   INPUTS: Tree pointer tree, pixel used to query
 *   OUTPUTS: none
 *   RETURN VALUE: the index to be used in palette
 *   SIDE EFFECTS: query all the pixel 
 */
unsigned int query_idx(octree* tree, uint16_t pix) {
    unsigned int res;
    unsigned int level_4_idx = get_index_4(pix);
    if ((tree -> four_pix_to_idx)[level_4_idx] == -1) {
        res = get_index_2(pix);
    } else {
        res = (tree -> four_pix_to_idx)[level_4_idx];
    }

    return res + QUERY_OFFSET;
}

/* 
 *   get_index_2
 *   DESCRIPTION: Get the corrospndoing index LEVEL_2_Arr
 *                 
 *   INPUTS: pixel value
 *   OUTPUTS: none
 *   RETURN VALUE: index to LEVEL_2_Arr
 *   SIDE EFFECTS: ge the appropriate index
 */
unsigned int get_index_2(uint16_t value) {
    unsigned int R = MASK_2_R & value;
    R = R >> 14;
    R = R << 4;
    unsigned int G = MASK_2_G & value;
    G = G >> 9;
    G = G << 2;
    unsigned int B = MASK_2_B & value;
    B = B >> 3;
    B = B << 0;

    unsigned int index = R | G | B;
    return index;
}

/* 
 *   get_index_4
 *   DESCRIPTION: Get the corrospndoing index LEVEL_4_Arr
 *                 
 *   INPUTS: pixel value
 *   OUTPUTS: none
 *   RETURN VALUE: index to LEVEL_4_Arr
 *   SIDE EFFECTS: ge the appropriate index
 */
unsigned int get_index_4(uint16_t value) {
    unsigned int R = MASK_4_R & value;
    R = R >> 12;                                        /* Right shift 12*/
    R = R << 8;                                         /* Left shift 8*/
    unsigned int G = MASK_4_G & value;
    G = G >> 7;                                         /* Right shift 7*/
    G = G << 4;                                         /* Left shift 4*/
    unsigned int B = MASK_4_B & value;
    B = B >> 1;                                         /* Right shift 1*/
    B = B << 0;                                         /* Left shift 0*/

    unsigned int index = R | G | B;
    return index;
}

/* 
 *   get_parent_index
 *   DESCRIPTION: Get the corrospndoing index in LEVEL_2_arr
 *                 
 *   INPUTS: pixel value
 *   OUTPUTS: none
 *   RETURN VALUE: index to LEVEL_2_Arr
 *   SIDE EFFECTS: ge the appropriate index when we have the index for level_4_arr
 */
unsigned int get_parent_index(unsigned int index) {
    unsigned int orig_R = CONVERT_R & index;
    orig_R = orig_R >> 10;                                  /* Right shift 10*/
    orig_R = orig_R << 4;                                   /* Left shift 4*/
    unsigned int orig_G = CONVERT_G & index;
    orig_G = orig_G >> 6;                                   /* Right shift 6*/
    orig_G = orig_G << 2;                                   /* left shift 2*/
    unsigned int orig_B = CONVERT_B & index;
    orig_B = orig_B >> 2;                                   /* Right shift 2*/
    orig_B = orig_B << 0;                                   /* Left shift 0*/

    unsigned int orig_index = orig_R | orig_G | orig_B;
    return orig_index;
}


