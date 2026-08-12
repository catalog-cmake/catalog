#include <SDL2/SDL.h>
#include <stdbool.h>
#include <stdio.h>

#define WINDOW_W 800
#define WINDOW_H 600
#define RECT_SIZE 80
#define SPEED 3

typedef struct {
  float x, y, vx, vy;
  Uint8 r, g, b;
} Ball;

int main() {
  if (SDL_Init(SDL_INIT_VIDEO) != 0) {
    fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
    return 1;
  }

  SDL_Window *win = SDL_CreateWindow("Catalog Example", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WINDOW_W, WINDOW_H, SDL_WINDOW_SHOWN);
  if (!win) {
    SDL_Quit();
    return 1;
  }

  SDL_Renderer *ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  if (!ren) {
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 1;
  }

  Ball balls[] = {
    {100, 100, SPEED, SPEED, 255, 80, 80},
    {300, 200, -SPEED, SPEED, 80, 255, 120},
    {500, 350, SPEED, -SPEED, 80, 160, 255},
    {200, 450, -SPEED, -SPEED, 255, 220, 60},
  };
  unsigned int nballs = sizeof(balls) / sizeof(balls[0]);

  bool running = 1;
  SDL_Event e;
  Uint32 frame = 0;

  while (running) {
    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_QUIT) running = 0;
      if (e.type == SDL_KEYDOWN) {
        if (e.key.keysym.sym == SDLK_ESCAPE || e.key.keysym.sym == SDLK_q) running = 0;
      }
    }

    SDL_SetRenderDrawColor(ren, 15, 15, 30, 255);
    SDL_RenderClear(ren);

    // Grid
    SDL_SetRenderDrawColor(ren, 30, 30, 55, 255);
    for (int x = 0; x < WINDOW_W; x += 40) SDL_RenderDrawLine(ren, x, 0, x, WINDOW_H);
    for (int y = 0; y < WINDOW_H; y += 40) SDL_RenderDrawLine(ren, 0, y, WINDOW_W, y);

    for (int i = 0; i < nballs; i++) {
      balls[i].x += balls[i].vx;
      balls[i].y += balls[i].vy;

      if (balls[i].x < 0 || balls[i].x + RECT_SIZE > WINDOW_W) balls[i].vx = -balls[i].vx;
      if (balls[i].y < 0 || balls[i].y + RECT_SIZE > WINDOW_H) balls[i].vy = -balls[i].vy;

      // Pulse
      Uint8 alpha = (Uint8)(180 + 75 * SDL_sinf((float)frame * 0.05f + i));
      SDL_SetRenderDrawColor(ren, balls[i].r, balls[i].g, balls[i].b, alpha);
      SDL_Rect rect = {(int)balls[i].x, (int)balls[i].y, RECT_SIZE, RECT_SIZE};
      SDL_RenderFillRect(ren, &rect);

      SDL_SetRenderDrawColor(ren, 255, 255, 255, 60);
      SDL_RenderDrawRect(ren, &rect);
    }

    SDL_RenderPresent(ren);
    frame++;
  }

  SDL_DestroyRenderer(ren);
  SDL_DestroyWindow(win);
  SDL_Quit();
  return 0;
}
