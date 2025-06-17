# Use a Node.js image based on Debian, which is much better for Puppeteer/Chromium
FROM public.ecr.aws/docker/library/node:18-slim AS base

# Install essential build tools and system dependencies for Chromium/Puppeteer
RUN apt-get update && apt-get install -y \
    wget gnupg \
    fonts-liberation \
    libappindicator3-1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libgbm1 \
    libgconf-2-4 \
    libgdk-pixbuf2.0-0 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    xdg-utils \
    # Specific dependencies often required by Puppeteer/Chrome
    libatk-bridge2.0-dev \
    libdrm-dev \
    libgbm-dev \
    libxshmfence-dev \
    # Clean up apt caches to keep image size down
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome Stable from Google's official repository
# WPPConnect often works better with Google Chrome than generic Chromium
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /usr/src/wpp-server

# Copy package.json and lock file to install dependencies
COPY package.json yarn.lock ./

# Install Node.js dependencies
# Use --frozen-lockfile if you have a yarn.lock
# ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true is not needed here as we install Chrome manually
RUN yarn install --production --pure-lockfile # Or npm install --production --force

# Copy the rest of your application code
COPY . .

# Build the application (as per your existing build stage)
RUN yarn build # Or npm run build

# --- Runtime Stage ---
# Use the same base image to ensure system dependencies are carried over
FROM base

# Set working directory
WORKDIR /usr/src/wpp-server

# Copy over only the necessary runtime files from the previous stage
# This includes node_modules and the built application code
COPY --from=base /usr/src/wpp-server/node_modules/ ./node_modules/
COPY --from=build /usr/src/wpp-server/dist/ ./dist/
# Copy other essential files like package.json (for scripts)
COPY --from=build /usr/src/wpp-server/package.json ./package.json
COPY --from=build /usr/src/wpp-server/yarn.lock ./yarn.lock

# Expose the correct port for Railway to route traffic
# This should match your Railway UI configuration (8080)
EXPOSE 8080

# Configure the environment variable for Puppeteer to find Chrome
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable

# The entrypoint for your WPPConnect Server application
# Ensure your application code is configured to listen on PORT 8080
# You might need to adjust your application's start command or config
# to make it listen on process.env.PORT or 8080 directly.
ENTRYPOINT ["node", "dist/server.js"]
CMD ["node", "dist/server.js", "--port", "8080"] # Pass port as arg, if server expects it.
# OR, if your server reads from process.env.PORT:
# CMD ["node", "dist/server.js"]
# Make sure your Railway env var PORT is set to 8080.
