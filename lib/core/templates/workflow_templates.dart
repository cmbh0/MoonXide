class WorkflowTemplates {
  static String flutterAndroidApk = r'''
name: android-apk-build

on:
  workflow_dispatch:
    inputs:
      build_type:
        description: Build type
        required: true
        default: debug
        type: choice
        options:
          - debug
          - release
      publish_release:
        description: Publish APK to GitHub Releases
        required: true
        default: false
        type: boolean
      release_tag:
        description: Release tag, example v1.0.0
        required: false
        default: latest

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      actions: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Java 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
          cache: gradle

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Build APK
        run: |
          if [ "${{ github.event.inputs.build_type }}" = "debug" ]; then
            flutter build apk --debug
          else
            flutter build apk --release
          fi

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-${{ github.event.inputs.build_type }}-apk
          path: build/app/outputs/flutter-apk/*.apk

      - name: Publish Release
        if: ${{ github.event.inputs.publish_release == 'true' }}
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ github.event.inputs.release_tag }}
          name: ${{ github.event.inputs.release_tag }}
          body: Built by MoonXide mobile IDE.
          files: build/app/outputs/flutter-apk/*.apk
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
''';
}