# SpringBoot 实现文件上传

## 一、代码实现

### 1.表单设置 multipart/form-data 请求

```html
<form
  role="form"
  th:action="@{/form/upload}"
  th:method="POST"
  enctype="multipart/form-data"
>
  <div class="form-group">
    <label for="exampleInputEmail1">Email address</label>
    <input
      type="email"
      name="email"
      class="form-control"
      id="exampleInputEmail1"
      placeholder="Enter email"
    />
  </div>
  <div class="form-group">
    <label for="exampleInputPassword1">username</label>
    <input
      type="password"
      name="username"
      class="form-control"
      id="exampleInputPassword1"
      placeholder="Password"
    />
  </div>
  // 单文件上传
  <div class="form-group">
    <label for="exampleInputFile">File input</label>
    <input type="file" name="avatar" id="exampleInputFile" />
    <p class="help-block">Example block-level help text here.</p>
  </div>
  // 多文件上传
  <div class="form-group">
    <label for="exampleInputFile">File input</label>
    <input type="file" name="photos" id="exampleInputFile1" multiple />
  </div>
  <div class="checkbox">
    <label> <input type="checkbox" /> Check me out </label>
  </div>
  <button type="submit" class="btn btn-primary">Submit</button>
</form>
```

### 2.Controller 层使用 Mutipart 类接收参数

```java
@PostMapping("/upload")
public String upload(@RequestParam String email,
                     @RequestParam String username,
                     @RequestPart MultipartFile avatar,
                     @RequestPart MultipartFile[] photos){

    // 存储文件操作
    if (Objects.nonNull(avatar)){
        String originalFilename = avatar.getOriginalFilename();
        try {
            File file = new File("E:\\cache\\" + photo.getOriginalFilename())
            avatar.transferTo(file);
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    // 存储文件操作
    if (Objects.nonNull(photos) && photos.length > 0){
        for (MultipartFile photo : photos) {
            if (Objects.nonNull(photo)){
                try {
                    File file = new File("E:\\cache\\" + photo.getOriginalFilename())
                    photo.transferTo(file);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
    }

    return "index";
}
```

## 二、Mutilpart 参数解析原理
