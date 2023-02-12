#include <cstdio>

using namespace std;

void print_masks(int layercontrol, int m_pri_ctrl)
{
    /* Draw layers (0 = sprites, 1-3 = tilemaps) */
    int l0 = (layercontrol >> 0x06) & 03;
    int l1 = (layercontrol >> 0x08) & 03;
    int l2 = (layercontrol >> 0x0a) & 03;
    int l3 = (layercontrol >> 0x0c) & 03;

    int primasks[8], i;
    int l0pri = (m_pri_ctrl >> 4 * l0) & 0x0f;
    int l1pri = (m_pri_ctrl >> 4 * l1) & 0x0f;
    int l2pri = (m_pri_ctrl >> 4 * l2) & 0x0f;
    int l3pri = (m_pri_ctrl >> 4 * l3) & 0x0f;

    /* take out the CPS1 sprites layer */
    if (l0 == 0) { l0 = l1; l1 = 0; l0pri = l1pri; }
    if (l1 == 0) { l1 = l2; l2 = 0; l1pri = l2pri; }
    if (l2 == 0) { l2 = l3; l3 = 0; l2pri = l3pri; }

    int mask0 = 0xaa;
    int mask1 = 0xcc;
    if (l0pri > l1pri) mask0 &= ~0x88;
    if (l0pri > l2pri) mask0 &= ~0xa0;
    if (l1pri > l2pri) mask1 &= ~0xc0;

    primasks[0] = 0xff;
    printf("FFFF ");
    for (i = 1; i < 8; i++)
    {
        if (i <= l0pri && i <= l1pri && i <= l2pri)
        {
            primasks[i] = 0xfe;
            goto next;
        }
        primasks[i] = 0;
        if (i <= l0pri) primasks[i] |= mask0;
        if (i <= l1pri) primasks[i] |= mask1;
        if (i <= l2pri) primasks[i] |= 0xf0;

        next:
        printf("%04X ", primasks[i] );
        if(i==3) printf("  ");
    }
}

int main() {
    for( int l0=0; l0<4; l0++ )
    for( int l1=0; l1<4; l1++ )
    for( int l2=0; l2<4; l2++ )
    for( int l3=0; l3<4; l3++ ) {
        if( l3==l2 || l3 == l1 || l3==l0 ) continue;
        if( l2 == l1 || l2==l0 ) continue;
        if( l1 == l0 ) continue;
        int lyr_ctrl = (l0<<6) | (l1<<8) | (l2<<10) | (l3<<12);
        for( int prio0=0; prio0<8; prio0++ )
        for( int prio1=0; prio1<8; prio1++ )
        for( int prio2=0; prio2<8; prio2++ )
        for( int prio3=0; prio3<8; prio3++ ) {
            if( prio0==prio1 || prio0==prio2 || prio0==prio3  ||
                prio1==prio2 || prio1==prio3 ||
                prio2==prio3
                ) continue;
            int prio_ctrl = prio0 | (prio1<<4) | (prio2<<8) | (prio3<<12);
            printf("%d%d%d%d/%04X -> ",l3,l2,l1,l0,prio_ctrl );
            print_masks( lyr_ctrl, prio_ctrl );
            puts("");
        }
    }
}